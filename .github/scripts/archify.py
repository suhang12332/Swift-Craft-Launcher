import os
import subprocess
import sys
import tempfile
import time
import argparse
import shutil
from pathlib import Path

LIPO = "/usr/bin/lipo"
FILE = "/usr/bin/file"
LDID = ""


class Log:
    log_buffer = []

    @staticmethod
    def append(message):
        Log.log_buffer.append(message)
        print(message)

    @staticmethod
    def save_log_to_file(file_path):
        with open(file_path, "w") as log_file:
            for log_message in Log.log_buffer:
                log_file.write(log_message + "\n")


def clean_bin(bin_path, arch):
    output_path = f"{bin_path}.{arch}"
    subprocess.check_output([LIPO, "-thin", arch, bin_path, "-output", output_path])
    os.remove(bin_path)
    os.rename(output_path, bin_path)


def sign_bin_with_ldid(bin_path, no_ent):
    try:
        entitlements = (
            subprocess.check_output([LDID, "-e", bin_path], stderr=subprocess.PIPE)
            .decode()
            .strip()
        )
    except subprocess.CalledProcessError:
        entitlements = ""

    if not entitlements or no_ent:
        status = subprocess.call([LDID, "-S", bin_path])
        if status != 0:
            Log.append(f"Failed to sign {bin_path}")
        return

    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp_file:
        tmp_file.write(entitlements.encode())
        tmp_file.flush()
        tmp_file_path = tmp_file.name

    status = subprocess.call([LDID, f"-S{tmp_file_path}", bin_path])
    os.remove(tmp_file_path)

    if status != 0:
        Log.append(f"Failed to sign {bin_path}")


def sign_bin_with_codesign(app_path, no_entitlements):
    entitlements_path = None
    if not no_entitlements:
        entitlements_path = extract_entitlements(app_path)

    cmd = ["/usr/bin/codesign", "--force", "--deep", "--sign", "-", app_path]
    if entitlements_path:
        cmd.append("--entitlements")
        cmd.append(entitlements_path)

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    if process.returncode == 0:
        Log.append(f"Successfully ad-hoc signed {app_path} with codesign")
    else:
        Log.append(f"Failed to ad-hoc sign {app_path} with codesign: {stderr.decode()}")

    if entitlements_path:
        os.remove(entitlements_path)


def extract_entitlements(app_path):
    cmd = ["/usr/bin/codesign", "-d", "--entitlements", "-", "--xml", app_path]
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    if process.returncode != 0:
        Log.append(f"Failed to extract entitlements: {stderr.decode()}")
        return None

    entitlements = stdout.decode()
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp_file:
        tmp_file.write(entitlements.encode())
        tmp_file_path = tmp_file.name
    return tmp_file_path


def duplicate_app(app_dir, output_dir):
    if not os.path.exists(output_dir):
        Log.append(f"Output dir does not exist: {output_dir}")
        return None

    output_app_dir = os.path.join(output_dir, os.path.basename(app_dir))
    os.makedirs(output_app_dir, exist_ok=True)

    rsync_p = subprocess.Popen(
        ["rsync", "-r", "-v", "-aHz", f"{app_dir}/", f"{output_app_dir}/"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    last = time.time()
    lines = 0
    total_time = 0
    for line in iter(lambda: rsync_p.stdout.readline(), b""):
        lines += 1
        total_time += time.time() - last
        last = time.time()
        sys.stdout.write(f"\r{round(lines / total_time, 2)} files/sec; {lines} ")

    rsync_p.wait()
    return output_app_dir


def is_mach(path):
    if os.path.islink(path):
        return False

    if not os.access(path, os.X_OK):
        return False

    output = subprocess.check_output([FILE, "--mime-type", path])
    return output.split()[-1].decode() == "application/x-mach-binary"


def is_universal(path, target_arch):
    output = (
        subprocess.check_output([LIPO, "-info", path]).decode().split(":")[-1].strip()
    )
    archs = output.split()

    if len(archs) == 1:
        return None

    if target_arch in archs:
        return target_arch

    if target_arch == "arm64" and "arm64e" in archs:
        return "arm64e"

    if target_arch == "arm64e" and "arm64" in archs:
        return "arm64"

    if target_arch != "i386" and "i386" in archs:
        if target_arch == "x86_64" and "x86_64" in archs:
            return "x86_64"
        if target_arch in ["arm64e", "arm64"] and "x86_64" in archs:
            return "x86_64"
        if "arm64e" in archs:
            return "arm64e"
        if "arm64" in archs:
            return "arm64"

    return None


def calculate_app_size(app_path):
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(app_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            # Skip if it's a symbolic link
            if not os.path.islink(fp):
                try:
                    total_size += os.path.getsize(fp)
                except OSError:
                    # Handle the case where the file is inaccessible
                    continue
    return total_size


def human_readable_size(size, decimal_places=2):
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024:
            return f"{size:.{decimal_places}f} {unit}"
        size /= 1024


def get_pid(app_path):
    cmd = ["ps", "aux"]
    ps_output = subprocess.check_output(cmd).decode().split("\n")
    for line in ps_output:
        if app_path in line:
            pid = int(line.split()[1])
            return pid
    return None


def open_app(app_path):
    try:
        process = subprocess.Popen(["open", app_path])
        time.sleep(10)  # Wait for the app to launch and initialize
        pid = get_pid(app_path)
        return pid
    except Exception as e:
        Log.append(f"Failed to open app: {e}")
        return None


def terminate_process(pid):
    try:
        subprocess.call(["kill", str(pid)])
        time.sleep(1)
        subprocess.call(["kill", "-9", str(pid)])  # Force kill if not terminated
    except Exception as e:
        Log.append(f"Failed to terminate process {pid}: {e}")


def main():
    global LDID
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-app",
        "--app_dir",
        nargs="+",
        type=str,
        required=True,
        help="The app to archify",
    )
    parser.add_argument(
        "-o",
        "--output_dir",
        type=str,
        default=os.getcwd(),
        help="Where the copy of the app is stored; defaults to working directory",
    )
    parser.add_argument(
        "-arch",
        "--arch",
        type=str,
        default=os.uname().machine,
        help="The architecture to archify to; default: python's architecture",
    )
    parser.add_argument(
        "-ld", "--ldid", type=str, help="The path to ldid for resigning the binaries"
    )
    parser.add_argument(
        "-Ns",
        "--no_sign",
        help="Do not sign the binaries with ldid",
        action="store_true",
    )
    parser.add_argument(
        "-Ne",
        "--no_entitlements",
        help="Do not sign the binaries with original entitlements with ldid",
        action="store_true",
    )
    parser.add_argument(
        "-cs",
        "--codesign",
        help="Ad-hoc sign the entire app with codesign",
        action="store_true",
    )
    parser.add_argument(
        "-l",
        "--no_launch",
        default=False,
        help="Do not launch the app to initialize; off by default",
        action="store_true",
    )

    args = parser.parse_args()
    app_dirs = sorted(set(args.app_dir))

    for dir in app_dirs:
        if not os.path.exists(dir):
            Log.append(f"App dir does not exist: {dir}")
            return

        output_dir = args.output_dir
        target_arch = args.arch

        if os.path.exists("/usr/local/bin/ldid"):
            LDID = "/usr/local/bin/ldid"

        if args.ldid:
            if os.path.exists(args.ldid):
                LDID = args.ldid
            else:
                Log.append("Specified ldid not found")
                if LDID:
                    Log.append(f"Using: {LDID}\n")
                else:
                    Log.append("No ldid found\n")

        Log.append(f"\nCreating a copy at {output_dir} ({os.path.basename(dir)})")
        output_app_dir = duplicate_app(dir, output_dir)
        if not output_app_dir:
            continue

        initial_size = calculate_app_size(dir)
        Log.append(f"Initial App Size: {human_readable_size(initial_size)}")

        if not args.no_launch:
            Log.append("Opening the app to initialize")
            app_pid = open_app(output_app_dir)
            if app_pid:
                Log.append("Terminating the app")
                terminate_process(app_pid)

        Log.append("\nExtracting the target binaries")
        for root, _, files in os.walk(output_app_dir):
            for file in files:
                file_path = os.path.join(root, file)
                if is_mach(file_path):
                    arch = is_universal(file_path, target_arch)
                    if arch:
                        Log.append(f"Cleaning {file_path}")
                        clean_bin(file_path, arch)
                        if LDID and not args.no_sign:
                            Log.append(f"Signing {file_path}")
                            sign_bin_with_ldid(file_path, args.no_entitlements)

        if args.codesign:
            Log.append("Ad-hoc signing the entire app with codesign")
            sign_bin_with_codesign(output_app_dir, args.no_entitlements)

        final_size = calculate_app_size(output_app_dir)
        Log.append(f"Final App Size: {human_readable_size(final_size)}")
        Log.append(
            f"\nSaved: {human_readable_size(initial_size-final_size)}, {100-(final_size/initial_size*100):.2f}%"
        )

        Log.save_log_to_file(os.path.join(output_dir, "process_log.txt"))


if __name__ == "__main__":
    main()