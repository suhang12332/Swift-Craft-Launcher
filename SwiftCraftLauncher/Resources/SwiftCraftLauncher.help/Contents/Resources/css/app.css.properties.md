# app.css 属性梳理文档

## 1. CSS 变量 (CSS Variables)

```css
:root {
    --base-color: #000;
    --border-color: #e6e6e6;
    --footer-color: #888;
    --footer-link-color: #555;
    --figcaption-itunes-color: #555;
    --figcaption-color: #888;
    --emphasis-color: #555;
    --link-color: #007aff;
    --subheading-color: #000;
    --hero-background-start: #ffffff;
    --hero-background-stop: #f2f2f2;
}
```

## 2. 基础重置样式

### 全局重置
- `*`: box-sizing, margin, padding
- `html`: text-size-adjust, font-family, font-size, line-height, color, text-rendering, font-smoothing
- 基础元素: address, caption, code, figcaption, pre, th

### 表单元素
- `button`: background, border, box-sizing, color, cursor, font, line-height, overflow, vertical-align
- `button:disabled`: cursor

## 3. 主要类名和选择器

### 3.1 标题相关
- `.Aside h2, h1`: margin, padding, outline, overflow, font-family, font-size, font-weight, line-height, color
- `sup`: top
- `.Subhead .Name`: font-size, margin, font-weight
- `.Subhead .Name+p`: margin-top
- `.landing .inner h1`: font-size, font-weight, letter-spacing, margin
- `div.Feature>.Name`: font-size, font-weight, line-height
- `div.Feature .FeatureBody .Name`: font-size, font-weight
- `div.Task>.Name`: font-size, font-weight, line-height

### 3.2 段落和文本
- `div.ParaLines, p`: margin, white-space, word-wrap, widows, orphans
- `div.ParaLines p, p p`: margin
- `.ParaLines`: margin-top
- `.ParaLines .footer`: font-size, color

### 3.3 列表
- `ul.ListSingle`: font-weight, margin-left
- `ul.ListSingle>li`: font-weight, list-style-image, padding-left, margin-left
- `ul.ListSingle li>p`: margin-top
- `ol.decimal>li`: margin-top, margin-bottom, list-style
- `ol.alpha>li`: margin-top, margin-bottom, list-style
- `ol, ul`: margin-top, margin-bottom
- `ol>li, ul>li`: margin-top, margin-bottom
- `ul>li`: list-style
- `ol>li`: list-style

### 3.4 代码
- `code`: font-family, overflow-wrap
- `td code, th code`: font-size, padding-top
- `.CodeLine, .CodeLines`: display, font-weight, white-space, word-break, overflow, text-overflow
- `.CodeLines`: margin-top, margin-bottom
- `.CodeLines>.CodeLine`: margin-top, margin-bottom

### 3.5 表格
- `table`: width, font-size, line-height, border-collapse, table-layout, text-align, margin
- `table th`: padding
- `table td`: padding
- `table td ol, table td p, table td ul`: margin-top, margin-bottom
- `table td>figure`: padding-left, margin-top, margin-bottom
- `table td>figure img`: max-width
- `table td>.TableDisplay, table td>ol li>p, table td>ul li>p, table td>ul>li`: margin-top, margin-bottom
- `table>tbody`: border-top
- `thead>tr`: border-top, border-bottom
- `table tbody tr`: border-bottom
- `p.TableHead`: font-weight
- `td, th`: vertical-align, text-align
- `table tbody>tr td>p.TableDisplay`: font-weight, vertical-align
- `table[data-type="1 column"]`: background-color, table-layout
- `table[data-type="Full Width"], table[data-type=Data]`: background-color

### 3.6 图片和图形
- `figure`: margin
- `figure img`: max-width, height, display
- `figure figcaption`: color, font-size, margin-top, margin-bottom, text-align
- `.topicIcon`: display, float, width, height, background-size, margin, top
- `.topicIcon img`: display
- `div.ParaLines img, p img`: height, width, position, top, vertical-align, pointer-events
- `figure:not(.app-icon) img, figure:not(.topicIcon) img`: width
- `figure.app-icon img, figure.topicIcon img`: width

### 3.7 链接
- `a`: position, outline, text-decoration, color
- `a:visited`: color
- `a:hover`: text-decoration
- `.no-hover a:hover`: text-decoration
- `a.xRef.Aside`: border-bottom
- `a.xRef.Aside:hover`: border-bottom-style, text-decoration
- `.link-external`: background-image, width, height, background-size, display, margin, position
- `.itunes-link`: cursor, color
- `.itunes-link:hover`: text-decoration
- `.itunes-link::after`: content, background-image, background-size, background-repeat, display, height, width, margin, position

### 3.8 警告和提示
- `li p.Caution, li p.Important, li p.Note, li p.Notice, li p.Tip`: margin-top
- `.TaskBody .Alert, div.note`: margin-top, margin-bottom
- `p.Caution, p.Warning`: margin-bottom
- `.Alert+.Alert`: margin-top
- `.yNote`: font-style, font-weight
- `ul+.Alert`: margin-left
- `.Alert+p`: margin-top

### 3.9 图标
- `strong.BlackIcon, strong.EUIcon, strong.Icon, strong.YellowIcon, strong.force-click, strong.siri, strong.tip, strong[class="3d-touch"]`: background, background-size, padding
- `strong.Icon`: background-image
- `strong.EUIcon`: background-image
- `strong.BlackIcon`: background-image
- `strong.force-click, strong.siri, strong.tip, strong[class="3d-touch"]`: background-image, background-size, padding
- `strong.tip`: background-image
- `strong.force-click, strong[class="3d-touch"]`: background-image

### 3.10 下载链接
- `.LinkDownload`: text-align, padding
- `.LinkDownload p`: margin-bottom, white-space
- `.LinkDownload p:first-child`: background, background-size, padding

### 3.11 标题中的图片
- `h1 img, h2 img, h3 img, h4 img, h5 img, h6 img`: display, height, width, vertical-align, pointer-events

### 3.12 着陆页 (Landing)
- `.landing`: text-align, display, flex-direction, justify-content
- `.landing .inner`: background, text-align, margin, padding
- `.landing .inner .Hero`: display, flex-direction, justify-content, align-items, align-content, border-bottom, padding-bottom
- `.landing .inner .Hero figure`: padding-right, margin
- `.landing .inner .Hero figure img`: min-height, max-height, min-width, width
- `.landing .inner .Hero figure+div`: text-align
- `.landing .inner h1+p`: display
- `.landing div.Feature`: padding
- `.landing div.Feature .FeatureBody .Subhead`: display, margin-bottom, padding-bottom, border-bottom
- `.landing div.Feature .FeatureBody .Subhead .Name`: font-size, font-weight, line-height, margin-bottom
- `.landing div.Feature .FeatureBody .Subhead p`: font-size, font-weight, line-height
- `.landing-toc-btn`: display, padding-left, margin, text-align
- `.landing-toc-btn li`: display, margin, list-style, padding
- `.landing-toc-btn li p`: display, margin, position, font-size, cursor
- `.landing-toc-btn li p .icon-info`: background, position, width, height, top, margin, display

### 3.13 单页着陆页
- `.single-landing.landing`: padding-top, text-align, margin
- `.single-landing .inner+p`: margin-top
- `.single-landing .inner .app-icon, .single-landing .inner .topicIcon`: float, top, width, height, background-size, display

### 3.14 设计版本 2 (data-designversion="2")
- `[data-designversion="2"] .landing`: display, flex-direction, justify-content
- `[data-designversion="2"] .landing .inner`: background-color, padding, margin
- `[data-designversion="2"] .landing .inner .Hero`: text-align, display, flex-direction, align-items, background, margin, padding, min-height
- `[data-designversion="2"] .landing .inner .Hero figure`: text-align, width
- `[data-designversion="2"] .landing .inner .Hero figure.app-icon`: width
- `[data-designversion="2"] .landing .inner .Hero figure.app-icon img`: max-width
- `[data-designversion="2"] .landing .inner .Hero figure img`: width, height, max-width
- `[data-designversion="2"] .landing .inner .Hero div`: width, padding-right
- `[data-designversion="2"] .landing .inner .Hero div p`: margin
- `[data-designversion="2"] .landing .inner .Hero div .Name+p, [data-designversion="2"] .landing .inner .Hero div .Name+span`: font-size, line-height, font-weight, letter-spacing
- `[data-designversion="2"] .landing .inner .Hero .app-icon+div`: width

### 3.15 章节标题 (Subhead)
- `.Subhead`: margin-top, margin-bottom
- `.Subhead>:last-child`: margin-bottom
- `.AppleTopic .Subhead[class*=graphicsizing]`: padding-bottom, margin-bottom, border-bottom
- `.AppleTopic .Subhead[class*=graphicsizing]:first-of-type`: padding-top, border-top
- `.Subhead[class*=graphicsizing] a::after`: content, background, height, width, display, margin, margin-bottom
- `.Subhead .Name`: font-size, margin-top, margin-bottom, font-weight

### 3.16 任务 (Task)
- `div.Task`: background-color, border-top, border-bottom, padding, margin
- `div.Task:hover .task-arrow`: background-image
- `div.Task.graphicsizing-small`: float, min-width
- `div.Task.graphicsizing-small figure`: width, float
- `div.Task.graphicsizing-small figure img`: max-width, height
- `div.Task.graphicsizing-small .TaskBody, div.Task.graphicsizing-small h2`: float, width
- `div.Task+.Task`: border-top-color, padding-top, margin-top
- `div.Task:first-child`: margin-top
- `div.Task>.Name`: width, box-sizing, text-align, position, margin, padding-top, padding-bottom, padding-right
- `div.Task>.Name .task-arrow`: background-image, position, background-size, width, height, top, right, transform, transform-style, transition
- `div.Task>.Name .TaskButtonName[aria-expanded=true] .task-arrow`: transform
- `div.Task>.Name:focus`: outline
- `div.Task>.Name .TaskButtonName`: text-align
- `div.Task.SoloTask .Name`: cursor
- `div.Task.SoloTask .Name:hover`: color
- `div.Task.SoloTask .task-arrow`: display
- `div.Task .TaskBody`: margin-top, margin-right, margin-bottom, padding-bottom, opacity, outline, max-height, overflow
- `div.Task .TaskBody>.Alert, div.Task .TaskBody>.Alert:first-child, div.Task .TaskBody>figure, div.Task .TaskBody>p, div.Task .TaskBody>p+p, div.Task .TaskBody>p:first-child`: margin-top
- `div.Task .TaskBody`: margin-left, padding-left
- `div.Task .TaskBody p`: margin-left

### 3.17 三栏布局 (Triptych)
- `.Triptych`: margin-top, margin-bottom
- `.Triptych .panel-container`: display, flex-wrap, margin
- `.Triptych .panel-container .Panel`: flex, padding, margin, width
- `.Triptych .panel-container .Panel .panel-content .Name`: font-size, font-weight, line-height, margin-bottom
- `.Triptych .panel-container .Panel p`: vertical-align
- `.Triptych figure, .Triptych+figure figure, .Triptych+figure+p figure`: margin
- `.Triptych p, .Triptych+figure p, .Triptych+figure+p p`: padding
- `.Triptych+figure+p`: width, margin

### 3.18 特性展示 (PassionPoints / Feature)
- `.PassionPoints`: padding-top, padding-bottom
- `.PassionPoints .hide-me`: display
- `.PassionPoints div.Feature`: position, padding, margin, text-align, font-size
- `.PassionPoints div.Feature>.Name`: margin, pointer-events
- `.PassionPoints div.Feature>.Name+p`: margin-bottom, line-height, pointer-events
- `.PassionPoints div.Feature .FeatureBody p`: line-height
- `.PassionPoints div.Feature .FeatureBody .Name`: margin-top, text-align, line-height, font-size, font-weight
- `.PassionPoints div.Feature .FeatureBody .Subhead`: display
- `.PassionPoints div.Feature .FeatureBody .Subhead>div`: width
- `.PassionPoints div.Feature .FeatureBody .Subhead figure`: max-width, align-self
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-left figure, .PassionPoints div.Feature .FeatureBody .Subhead:nth-child(odd) figure`: padding-left, padding-right
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-right, .PassionPoints div.Feature .FeatureBody .Subhead:nth-child(even)`: flex-direction
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-left`: flex-direction
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-right`: flex-direction
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-top`: flex-direction
- `.PassionPoints div.Feature .FeatureBody .Subhead.figure-bottom`: flex-direction
- `.PassionPoints div.Feature .FeatureBody .Subhead figure`: margin
- `.PassionPoints div.Feature .FeatureBody .Subhead p`: text-align, padding
- `.PassionPoints div.Feature .FeatureBody>figure:last-of-type`: padding-top, border-top, margin-top
- `.PassionPoints div.Feature .FeatureBody .Outro`: border-top, padding-top, text-align
- `.PassionPoints div.Feature .FeatureBody .Outro figure`: margin
- `.PassionPoints div.Feature .FeatureBody .Outro.outro-center footer, .PassionPoints div.Feature .FeatureBody .Outro.outro-center p`: text-align
- `.PassionPoints div.Feature .FeatureBody .Subhead+.Outro`: border-top, padding-top

### 3.19 页脚
- `.footer, footer`: font-size, color, margin-top
- `.footer em, footer em`: color
- `.footer a, .footer a:visited, footer a, footer a:visited`: color
- `figure+p.footer`: margin-bottom

### 3.20 其他元素
- `address`: font-style
- `address p`: margin-top, margin-bottom
- `address+p`: margin-top
- `.Example`: margin-left, margin-right
- `.Copyright`: font-size, padding-bottom
- `.Copyright h1`: display
- `.Copyright p:nth-of-type(1)`: margin-bottom
- `.Copyright p:nth-of-type(2)`: margin-top
- `.Copyright p`: font-size, letter-spacing
- `.HIStrings`: margin-top, margin-bottom
- `.HIStrings p`: margin-bottom
- `.HIStrings>p`: margin-bottom
- `.HIStrings:first-child`: padding-top, margin-top
- `.HIStrings+.HIStrings`: margin-top
- `.HIStrings em.Term`: color
- `.HIStrings strong.Term`: color
- `.HISubString`: margin-top, margin-bottom, display, margin-left, padding-left
- `.HISubString>.HISubString`: margin-top, display, margin-left, padding-left
- `.Comment`: color
- `.Comment::before`: content, font-weight
- `[data-change-bar=true]`: border-left, background-color, padding-left, padding-right
- `.ListDescriptor+.Alert`: margin-top
- `dl dd, dl dt`: display, margin
- `dl dt`: float, font-weight
- `dl dt:after`: content
- `ul .Example`: margin-left
- `.Outro`: padding-top, padding-bottom
- `video`: max-width
- `small`: font-variant-caps, font-size
- `span.NoBreak`: white-space
- `em small`: font-size

### 3.21 语言特定样式
- `.Aside h2:lang(hi), .Aside h2:lang(th), .Aside h2:lang(vi), h1:lang(hi), h1:lang(th), h1:lang(vi)`: line-height
- `em:lang(ja), em:lang(ko), em:lang(zh)`: font-style, font-weight
- `ol>li:lang(ar)`: list-style-type
- `ol>li:lang(he)`: list-style-type
- `ol>li:lang(hi)`: list-style-type
- `.landing .inner h1:lang(ar), .landing .inner h1:lang(he), .landing .inner h1:lang(ja), .landing .inner h1:lang(ko), .landing .inner h1:lang(th), .landing .inner h1:lang(zh)`: letter-spacing
- `.loc-prefers-small-font:lang(...)`: font-size

### 3.22 响应式设计
- `.prefers-small-font`: font-size
- `.prefers-smaller-font`: font-size
- `.prefers-hyphenation`: word-wrap, overflow-wrap, hyphens

### 3.23 方向 (RTL/LTR)
- `[dir=rtl]`: 各种 RTL 特定样式
- `[dir=ltr]`: 各种 LTR 特定样式

### 3.24 AppleTopic 特定样式
- `.AppleTopic .ListDescriptor+p, .AppleTopic>div>p:last-child`: margin-top
- `.AppleTopic .Subhead[class*=graphicsizing]`: padding-bottom, margin-bottom, border-bottom
- `.AppleTopic .Triptych .panel-container .panel`: flex-direction, align-items
- `.AppleTopic .Triptych .panel-container .panel figure`: min-width, max-width, padding-bottom

### 3.25 主内容区
- `.main[dir=rtl]`: text-align, direction
- `.main[dir=rtl] [dir=ltr]`: text-align

### 3.26 反馈表单 (#feedback)
- `#feedback`: float, clear, position, padding-top, margin-top, margin-bottom, text-align
- `#feedback a`: text-transform, cursor
- `#feedback a:hover`: text-transform
- `.no-hover #feedback a:hover`: text-transform
- `#feedback .choices-label, #feedback .confirm, #feedback .solicit`: transition, position, top, left, right, margin, opacity, z-index
- `#feedback .choices-label[aria-hidden=true], #feedback .confirm[aria-hidden=true], #feedback .solicit[aria-hidden=true]`: overflow, opacity, z-index
- `#feedback .choices-label, #feedback .confirm`: font-weight
- `#feedback form`: transition, padding-top, padding-bottom, opacity, max-height, outline-style
- `#feedback form[aria-hidden=true]`: overflow, opacity, padding-top, padding-bottom, max-height
- `#feedback form[aria-hidden=false] .choices label`: margin-top, margin-bottom
- `#feedback .choices-label[aria-hidden=false], #feedback .confirm[aria-hidden=false], #feedback .solicit[aria-hidden=false], #feedback form[aria-hidden=false]`: transition-delay
- `#feedback .choices label`: position, display, padding, transition
- `#feedback .choices input`: position, top, left
- `#feedback textarea`: resize, height, width, background, color, padding
- `#feedback button`: font-size, line-height, font-weight, background-color, background, border-color, border-width, border-style, border-radius, color, cursor, display, min-width, padding-left, padding-right, padding-top, text-align, white-space, margin-right
- `#feedback button:hover`: background-color, background, border-color, text-decoration
- `#feedback button:focus`: box-shadow, outline
- `#feedback button:active`: background-color, background, border-color, outline
- `#feedback button:disabled`: border-color, color, cursor, opacity
- `#feedback button[name=cancel]`: border-color, background-color, background

### 3.27 调试 (#debug)
- `#debug`: border-top, clear
- `#debug table`: max-width
- `#debug table th`: background-color, color, border
- `#debug table td, #debug table th`: padding, overflow-wrap
- `#debug table tr`: border-left, border-right
- `#debug table tr:nth-child(even)`: background
- `#debug table tr:nth-child(odd)`: background

### 3.28 版权信息
- `.copyright-text`: display, padding-top, text-align, white-space, color, font-size, clear

### 3.29 深色模式
- `.dark-mode-enabled`: color-scheme
- `.dark-mode-enabled`: CSS 变量覆盖
- `.dark-mode-enabled` 各种元素: color
- `.dark-mode-enabled #feedback textarea`: background

### 3.30 Body 样式
- `body`: min-width, max-width, padding

### 3.31 目录列表 (toc-list) - 自定义添加
- `.toc-list`: list-style, padding-left, margin
- `.toc-list li`: margin-bottom, padding-left
- `.toc-list li:last-child`: margin-bottom
- `.toc-list li a`: color, font-weight
- `.toc-list li p`: margin-top, margin-bottom

## 4. 媒体查询

### 4.1 打印样式
- `@media print`: `.copyright-text`, `div.Task .TaskBody`, `#feedback`

### 4.2 屏幕尺寸
- `@media all and (max-width:736px)`: 各种响应式样式
- `@media all and (max-width:1069px)`: 各种响应式样式
- `@media all and (max-width:320px)`: `.landing .inner h1`
- `@media all and (max-width:440px)`: figure 相关样式
- `@media all and (min-width:736px) and (max-width:1069px)`: Triptych 样式
- `@media all and (min-width:1069px)`: Triptych 样式
- `@media all and (min-width:736px)`: Subhead graphicsizing 样式

### 4.3 设备像素比
- `@media (-webkit-min-device-pixel-ratio:2)`: `.Task`

### 4.4 颜色方案
- `@media only screen and (prefers-color-scheme:dark)`: `.dark-mode-enabled #feedback textarea`

## 5. 特殊属性

### 5.1 文本渲染
- `text-rendering`: optimizeLegibility
- `-webkit-text-rendering`: optimizeLegibility
- `-webkit-font-smoothing`: antialiased
- `-moz-osx-font-smoothing`: grayscale
- `-moz-font-feature-settings`: 'liga','kern'

### 5.2 打印颜色调整
- `-webkit-print-color-adjust`: exact

### 5.3 变换和过渡
- `transform`: rotateX
- `transform-style`: preserve-3d
- `transition`: transform, opacity, max-height, padding

### 5.4 Flexbox
- `display`: flex
- `flex-direction`: column, row, row-reverse, column-reverse
- `justify-content`: center, flex-start
- `align-items`: center, flex-start
- `align-content`: flex-start
- `flex`: 1 150px, 1 100%
- `flex-wrap`: wrap

### 5.5 定位
- `position`: relative, absolute
- `top`, `right`, `left`, `bottom`: 各种值
- `z-index`: 1, 2

### 5.6 显示
- `display`: block, inline-block, none, flex
- `visibility`: hidden
- `opacity`: 0, 1

### 5.7 溢出
- `overflow`: visible, hidden
- `overflow-wrap`: break-word
- `text-overflow`: ellipsis

### 5.8 背景
- `background`: url(), linear-gradient(), 0 0, transparent
- `background-color`: transparent, #fff, #1e2022
- `background-image`: url()
- `background-size`: contain, 1.2rem .984rem, 1.4em 1.4em
- `background-position`: left top, right top, center left
- `background-repeat`: no-repeat
- `background-position-y`: 1px

### 5.9 边框
- `border`: 0, none, 1px solid, 2px solid, 2px dashed
- `border-top`, `border-bottom`, `border-left`, `border-right`: 各种样式
- `border-color`: var(--border-color), #007aff, #07c
- `border-width`: 1px, .5px
- `border-style`: solid, dotted, dashed
- `border-radius`: 3px, 4px
- `border-collapse`: collapse
- `border-spacing`: 0

### 5.10 间距
- `margin`: 各种值
- `padding`: 各种值
- `margin-top`, `margin-bottom`, `margin-left`, `margin-right`: 各种值
- `padding-top`, `padding-bottom`, `padding-left`, `padding-right`: 各种值

### 5.11 尺寸
- `width`: 100%, auto, 40px, 50%, 30%, 60%, 75%, 80%
- `height`: auto, 30px, 64px, 6em, 1.2em, 1.4em
- `min-width`: 30px, 16px, 100%, 0
- `max-width`: 100%, 200px, 350px, 400px, 700px, 900px, 1442px
- `min-height`: 0, 64px, 300px
- `max-height`: 0, 800px, 64px, unset

### 5.12 字体
- `font-family`: -apple-system, 'SF Mono', 'SF Pro Display', 'SF Pro Text', monospace
- `font-size`: 各种 rem, em, px 值
- `font-weight`: 400, 500, 600, 700
- `font-style`: normal, italic
- `line-height`: 1.3, 1.5, 1.43, 1.4545, 1.9375
- `letter-spacing`: -.02em, -.01em, -.005em, -.016em, .011em, .012em, .015em, .016em, .018em
- `font-variant-caps`: all-small-caps

### 5.13 文本
- `text-align`: left, right, center
- `text-decoration`: none, underline
- `text-transform`: none, underline
- `white-space`: pre-line, pre-wrap, nowrap, normal
- `word-wrap`: break-word
- `word-break`: break-word
- `widows`: 3
- `orphans`: 3
- `hyphens`: auto
- `-webkit-hyphens`: auto
- `-ms-hyphens`: auto

### 5.14 颜色
- `color`: var(--base-color), var(--link-color), var(--subheading-color), #000, #fff, #007aff, #0066cc, #0052a3, #5ac8fa, #7dd3fc, red, #fff
- `background-color`: transparent, #fff, #1e2022, #007aff, #147bcd, #0067b9, #595959, #ffc8c8, #ddd, #2d2d2f

### 5.15 光标
- `cursor`: pointer, text, default

### 5.16 其他
- `box-sizing`: border-box, content-box
- `vertical-align`: baseline, top, text-bottom, inherit, -.2em, -.1em
- `float`: left, right, none
- `clear`: both
- `outline`: 0, none
- `resize`: none
- `list-style`: none, disc, decimal, lower-alpha, arabic-indic, hebrew, devanagari
- `list-style-image`: url(img/square-bullet.svg)
- `list-style-type`: arabic-indic, hebrew, devanagari
- `pointer-events`: none
- `mix-blend-mode`: multiply, screen
- `object-fit`: contain
- `page-break-inside`: avoid
- `color-scheme`: light dark

## 6. 伪类和伪元素

### 6.1 伪类
- `:hover`
- `:visited`
- `:focus`
- `:active`
- `:disabled`
- `:first-child`
- `:last-child`
- `:nth-child(even)`
- `:nth-child(odd)`
- `:nth-of-type(1)`
- `:nth-of-type(2)`
- `:not(.app-icon)`
- `:not(.topicIcon)`
- `:lang(ar)`, `:lang(he)`, `:lang(hi)`, `:lang(ja)`, `:lang(ko)`, `:lang(th)`, `:lang(zh)`, `:lang(de)`, `:lang(es)`, `:lang(es-mx)`, `:lang(fi)`, `:lang(nb)`, `:lang(nl)`, `:lang(no)`, `:lang(pl)`, `:lang(pt-br)`, `:lang(pt-pt)`, `:lang(ru)`, `:lang(sv)`, `:lang(tr)`

### 6.2 伪元素
- `::before`: content
- `::after`: content, background-image, background-size, background-repeat, display, height, width, margin, position, transform

## 7. 数据属性选择器

- `[data-designversion="2"]`
- `[data-change-bar=true]`
- `[data-type="1 column"]`
- `[data-type="Full Width"]`
- `[data-type=Data]`
- `[data-istaskopen=false]`
- `[dir=rtl]`
- `[dir=ltr]`
- `[class*=graphicsizing]`
- `[aria-hidden=true]`
- `[aria-hidden=false]`
- `[aria-expanded=true]`

## 8. 组合选择器

- 后代选择器: `.parent .child`
- 子选择器: `.parent>.child`
- 相邻兄弟选择器: `.element+element`
- 通用兄弟选择器: `.element~element`
- 属性选择器: `[attribute]`, `[attribute=value]`, `[attribute*=value]`
- 类选择器组合: `.class1.class2`
- 多选择器: `selector1, selector2`

