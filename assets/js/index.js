// 页面加载完成后隐藏加载动画 - 已恢复
window.addEventListener('load', function () {
    const loader = document.querySelector('.loader');
    loader.style.opacity = '0';
    loader.style.visibility = 'hidden';

    // 初始化进度条动画
    document.querySelectorAll('.progress-fill').forEach(fill => {
        const width = fill.getAttribute('data-width');
        fill.style.width = width;
    });
});

// 滚动动画激活
document.addEventListener('DOMContentLoaded', function () {
    const navbar = document.getElementById('navbar');
    const backButton = document.getElementById('back-to-top');
    const currentYear = document.querySelector('.copyright p:last-child');

    // 更新版权年份
    if (currentYear) {
        currentYear.innerHTML = currentYear.innerHTML.replace('2025', new Date().getFullYear());
    }

    // 导航栏滚动效果
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }

        // 显示/隐藏回到顶部按钮
        if (window.scrollY > 500) {
            backButton.classList.add('visible');
        } else {
            backButton.classList.remove('visible');
        }
    });

    // 滚动动画
    const featureObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('.feature-card, .tech-card').forEach(card => {
        featureObserver.observe(card);
    });

    // 平滑滚动
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                window.scrollTo({
                    top: target.offsetTop - 80,
                    behavior: 'smooth'
                });
            }
        });
    });

    // 回到顶部按钮点击事件
    backButton.addEventListener('click', () => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });
});