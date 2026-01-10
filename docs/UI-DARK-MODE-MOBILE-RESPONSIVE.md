# UI/UX：深色模式 & 移动端响应式（Frontend）

本文档描述 OpenMeta 前端的主题系统（Light/Dark）、响应式布局与移动端体验优化实现。

## 主题（Dark Mode）

### 功能

- 自动检测系统主题：`prefers-color-scheme`
- 手动切换：页面右上角「浅色/深色」按钮
- 用户偏好持久化：`localStorage['openmeta-theme']` 保存 `light | dark`
- 页面加载即应用主题（避免 FOUC）：`frontend/index.html` 在 Vue 挂载前写入 `document.documentElement.dataset.theme`

### CSS 变量

主题通过 `data-theme` + CSS 变量实现：

- `frontend/src/styles/light.css`
- `frontend/src/styles/dark.css`
- `frontend/src/styles/variables.css`

组件内禁止硬编码颜色值（统一使用 `var(--...)`）。

### Composable

- `frontend/src/hooks/useTheme.ts`
  - `theme`: 当前主题（ref）
  - `isDark`: 是否深色模式（computed）
  - `toggleTheme()`: 切换主题
  - `setTheme(theme)`: 设置主题并持久化
  - `clearThemePreference()`: 清除用户偏好（回到跟随系统）

## 响应式布局

断点规则（与需求对齐）：

- xs: `< 480px`：单列
- sm: `480px - 768px`：单列优化
- md: `768px - 1024px`：两列（左侧历史 + 主区域）
- lg: `>= 1024px`：三列（左侧历史 + 结果 + 右侧提示）

对应样式文件：`frontend/src/styles/responsive.css`。

## 移动端体验优化

- 触控友好：移动端 `button/input` 最小高度 44px
- 虚拟键盘遮挡优化：`SearchBar` 输入框 `focus` 时触发 `scrollIntoView({ block: 'center' })`
- 搜索历史抽屉：移动端显示「历史」按钮，打开侧边抽屉（`HistoryDrawer.vue`）
- 长按复制：搜索结果项开启文本选择（`user-select: text`）

## 简单测试清单

### 深色模式

1. 系统切换为深色（macOS/iOS/Android），首次打开页面应自动跟随
2. 点击右上角主题按钮切换主题
3. 刷新页面，主题保持不变（localStorage 生效）

### 响应式

- iPhone SE / 375px：单列布局；搜索框 100%；按钮可点击
- iPhone 12 / 390px：同上
- iPad / 768px：两列布局（左侧历史，右侧主内容）
- Desktop / 1024px+：三列布局（右侧提示可见）
