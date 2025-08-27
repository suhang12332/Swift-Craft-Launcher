# 添加资源
启动器支持从Curseforge和Modrinth自动下载Mod、资源包(或称材质包)、光影、数据包并添加到游戏。

## 3.1 添加Mod
> 原版MC不支持加载Mod，若您想安装Mod，请确保您正确安装了Mod加载器。
- 1-2.在左侧“游戏列表”选择您想安装Mod的游戏，并点击顶部按钮前往“资源库”
![general1](/resources/addresources/general1.png)
- 3-5.在顶部选择“模组”选项，在右侧搜索栏搜索您想添加的Mod名，找到合适的Mod后点击“安装”
![mod2](/resources/addresources/mod2.png)
- 6-7.部分Mod可能会显示如图所示界面，这是因为该Mod需要其他Mod作为前置来运行，不过不用担心，点击“下载所有依赖并继续”后，启动器会为您自动安装他们，Mod安装完成后点击顶部按钮返回“已安装”
![mod3](/resources/addresources/mod3.png)
> 若您不想使用自动安装依赖功能，可以在启动器设置处关闭
- 8.当“已安装”页面出现您刚刚下载的Mod时，意味着您的Mod已安装完毕
![mod4](/resources/addresources/mod4.png)
- 9.此时启动游戏即可看到Mod已经被正常加载
![mod5](/resources/addresources/mod5.png)

## 3.2 添加资源包
- 1-2.在左侧“游戏列表”选择您想安装Mod的游戏，并点击顶部按钮前往“资源库”
![general1](/resources/addresources/general1.png)
- 3-6.在顶部选择“资源包”选项，在右侧搜索栏搜索您想添加的资源包名，找到合适的资源包后点击“安装”，完成后点击顶部按钮返回“已安装”
![resourcespack2](/resources/addresources/resourcespack2.png)
- 7.当“已安装”页面出现您刚刚下载的资源包时，意味着您的资源包已安装完毕
![resourcespack3](/resources/addresources/resourcespack3.png)
- 8.此时启动游戏即可看到资源包已经被正常识别
![resourcespack4](/resources/addresources/resourcespack4.png)
> 点击小三角形即可加载资源包

## 3.3 添加光影
> 若您想安装光影，请确保您正确安装了Optifine、Iris Shader、Oculus中的一种。
- 1-2.在左侧“游戏列表”选择您想安装Mod的游戏，并点击顶部按钮前往“资源库”
![general1](/resources/addresources/general1.png)
- 3-6.在顶部选择“光影”选项，在右侧搜索栏搜索您想添加的光影名，找到合适的光影后点击“安装”，完成后点击顶部按钮返回“已安装”
![shader2](/resources/addresources/shader2.png)
- 7.当“已安装”页面出现您刚刚下载的光影时，意味着您的光影已安装完毕
![shader3](/resources/addresources/shader3.png)
- 8.此时启动游戏即可看到光影已经被正常识别
![shader4](/resources/addresources/shader4.png)
> 点击你下载的光影文件即可加载该光影包

## 3.4 添加数据包
> 数据包为玩家自定义Minecraft的游戏内容提供了更多新方法，包括但不限于配置进度、配方、战利品表、魔咒、伤害类型、生物变种和世界生成等。
- 添加数据包功能正在开发中，敬请期待...

## 3.5 手动添加资源
- 若您在资源库没有搜到您需要的资源，那么这部分内容是为您准备的
- 请先准备好你的资源文件，Mod(.jar)、资源包(.zip)、数据包(.zip)、光影包(.zip)、配置文件(.toml .json .yaml等)、存档文件(文件夹)
- 1-2.在左侧“游戏列表”选择您想安装资源的游戏，并点击顶部“路径”按钮
![manual1](/resources/addresources/manual1.png)
- 3.启动器会打开“访达”并自动跳转到游戏所在的目录，如图所示
![manual2](/resources/addresources/manual2.png)
- 4.将资源文件放入对应的文件夹
> config:配置文件夹\
> mods:Mod文件夹\
> resourcespack:资源包文件夹\
> saves:存档文件夹\
> shaderpacks:光影包文件夹
- 若您添加的是配置文件、Mod，请重启游戏使其生效；其余各项无需重启。