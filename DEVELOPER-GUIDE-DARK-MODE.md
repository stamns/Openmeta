# 深色模式和响应式设计 - 开发者快速指南

## 快速开始

### 1. 使用主题 Hook

```vue
<script setup lang="ts">
import { useTheme } from '@/hooks/useTheme';

// 获取主题管理 API
const {
  theme,              // 当前主题：'light' | 'dark'
  isDark,             // 是否为深色模式
  toggleTheme,        // 切换主题
  setTheme,           // 设置指定主题
  hasStoredPreference // 是否有保存的用户偏好
} = useTheme();
</script>
```

### 2. 使用主题变量

在 CSS 中使用预定义的 CSS 变量：

```css
.my-component {
  /* 颜色 */
  background: var(--bg-primary);
  color: var(--text-primary);
  border-color: var(--border-color);

  /* 强调色 */
  accent-color: var(--accent-color);

  /* 背景变体 */
  background-hover: var(--surface-hover);
  background-secondary: var(--bg-secondary);

  /* 文字变体 */
  text-secondary: var(--text-secondary);
  text-muted: var(--text-muted);

  /* 状态颜色 */
  success-color: var(--success-color);
  error-color: var(--error-color);
  warning-bg: var(--warning-bg);

  /* 间距 */
  padding: var(--space-4);
  border-radius: var(--radius-md);

  /* 过渡 */
  transition: background var(--transition-theme);

  /* 阴影 */
  box-shadow: var(--shadow);
}
```

### 3. 响应式样式

使用预定义的断点：

```css
/* 移动优先：默认为小屏样式 */
.container {
  padding: 16px;
  font-size: 14px;
}

/* 小屏：480px - 767px */
@media (min-width: 480px) {
  .container {
    padding: 18px;
    font-size: 15px;
  }
}

/* 中屏：768px - 1023px（平板） */
@media (min-width: 768px) {
  .container {
    padding: 24px;
    font-size: 16px;
  }
}

/* 大屏：1024px+（桌面） */
@media (min-width: 1024px) {
  .container {
    padding: 32px;
    font-size: 16px;
  }
}
```

## 可用的 CSS 变量

### 颜色变量

```css
/* 主色调 */
--bg-primary      /* 主背景色 */
--bg-secondary    /* 次要背景色 */
--bg-tertiary     /* 第三背景色 */

/* 文字颜色 */
--text-primary    /* 主要文字 */
--text-secondary  /* 次要文字 */
--text-muted      /* 弱化文字 */

/* 边框 */
--border-color    /* 边框颜色 */

/* 强调色 */
--accent-color    /* 强调色 */
--accent-hover    /* 悬停时强调色 */
--on-accent       /* 在强调色上的文字 */

/* 状态颜色 */
--success-color   /* 成功 */
--error-color     /* 错误 */
--warning-bg      /* 警告背景 */
--warning-text    /* 警告文字 */
--warning-border  /* 警告边框 */

/* 表面颜色 */
--surface-bg      /* 表面背景 */
--surface-hover   /* 表面悬停 */

/* 输入框 */
--input-bg        /* 输入框背景 */
--card-bg         /* 卡片背景 */

/* 代码块 */
--code-bg         /* 代码背景 */
--code-text       /* 代码文字 */

/* 严重错误 */
--critical-bg     /* 严重错误背景 */
--critical-border /* 严重错误边框 */
--critical-text   /* 严重错误文字 */

--error-bg        /* 错误背景 */
--error-border    /* 错误边框 */
--error-text      /* 错误文字 */
```

### 间距变量

```css
--radius-sm: 8px;
--radius-md: 12px;
--radius-lg: 16px;

--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 20px;
--space-6: 24px;
```

### 阴影变量

```css
--shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
--shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
--shadow-md: 0 10px 24px rgba(0, 0, 0, 0.12);
```

### 过渡变量

```css
--transition-fast: 0.15s;
--transition-theme: 0.25s;
```

### 特殊变量

```css
--safe-area-bottom: env(safe-area-inset-bottom); /* iOS 安全区域 */
--focus-ring: 0 0 0 3px rgba(0, 102, 204, 0.25); /* 焦点环 */
--overlay-bg: rgba(0, 0, 0, 0.5); /* 遮罩背景 */
--spinner-track: rgba(255, 255, 255, 0.35); /* 加载动画轨道 */
```

## 响应式断点

```css
/* 断点定义 */
xs: < 480px      /* 超小屏 - 移动手机 */
sm: 480px - 767px /* 小屏 - 大屏手机 */
md: 768px - 1023px /* 中屏 - 平板电脑 */
lg: 1024px+      /* 大屏 - 桌面电脑 */
```

## 可访问性工具类

### 焦点样式
```css
/* 所有可交互元素都应该有清晰的焦点样式 */
:focus-visible {
  outline: 2px solid var(--accent-color);
  outline-offset: 2px;
}
```

### 屏幕阅读器专用
```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
```

### 触摸目标
```css
/* 移动端确保触摸目标足够大 */
@media (max-width: 767px) {
  button, input[type='text'], .action-btn {
    min-height: 44px;
    min-width: 44px;
  }
}
```

## ARIA 标签最佳实践

### 按钮
```vue
<button
  type="button"
  :aria-label="isDark ? '切换为浅色模式' : '切换为深色模式'"
  :aria-pressed="isDark"
  @click="toggleTheme"
>
  <span aria-hidden="true">🌙</span>
</button>
```

### 输入框
```vue
<input
  v-model="query"
  type="search"
  aria-label="搜索关键词"
  aria-describedby="search-hint"
/>

<span id="search-hint" class="sr-only">
  输入关键词后按回车搜索
</span>
```

### 状态更新
```vue
<div
  role="status"
  aria-live="polite"
  class="loading-indicator"
>
  {{ loading ? '正在搜索...' : '' }}
</div>
```

### 警告和错误
```vue
<div
  role="alert"
  aria-live="assertive"
  class="error-message"
>
  {{ errorMessage }}
</div>
```

### 模态框/抽屉
```vue
<div
  v-if="open"
  role="dialog"
  aria-modal="true"
  aria-label="搜索历史"
>
  <!-- 内容 -->
</div>
```

## 移动端优化

### 1. 虚拟键盘处理
```typescript
// 在输入框获得焦点时滚动到可见区域
function ensureVisible() {
  const el = inputEl.value;
  if (!el) return;

  window.setTimeout(() => {
    el.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }, 300);
}
```

### 2. 防止文本选择（移动端优化）
```css
/* 如果不希望用户选择某些文本 */
.no-select {
  -webkit-user-select: none;
  user-select: none;
}

/* 如果希望用户可以选择文本（如搜索结果） */
.selectable {
  -webkit-user-select: text;
  user-select: text;
}
```

### 3. 触摸反馈
```css
/* 为按钮添加触摸反馈 */
button {
  transition: background var(--transition-fast);
}

button:active {
  background: var(--surface-hover);
  transform: scale(0.98);
}
```

## 布局系统

### 1. 页面布局
```css
.page {
  min-height: 100svh;  /* 使用 svh 而不是 vh，避免移动端地址栏问题 */
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px 16px;
}
```

### 2. 网格布局
```css
.layout {
  display: grid;
  grid-template-columns: 1fr;  /* 默认单列 */
  gap: 16px;
}

@media (min-width: 768px) {
  .layout {
    grid-template-columns: 240px 1fr;  /* 两列 */
  }
}

@media (min-width: 1024px) {
  .layout {
    grid-template-columns: 260px 1fr 280px;  /* 三列 */
  }
}
```

### 3. 卡片样式
```css
.card {
  background: var(--surface-bg);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
}
```

## 测试建议

### 1. 测试主题切换
```typescript
// 在浏览器控制台测试
import { useTheme } from '@/hooks/useTheme';

const { isDark, toggleTheme } = useTheme();

// 切换主题
toggleTheme();

// 设置深色主题
const { setTheme } = useTheme();
setTheme('dark');

// 清除用户偏好（跟随系统）
const { clearThemePreference } = useTheme();
clearThemePreference();
```

### 2. 测试响应式
使用浏览器开发者工具的设备模拟器：
- iPhone SE (375px)
- iPhone 12 (390px)
- iPad (768px)
- Desktop (1024px+)

### 3. 测试可访问性
- 使用 Tab 键导航
- 测试屏幕阅读器（NVDA、VoiceOver）
- 检查焦点状态
- 测试高对比度模式

## 常见问题

### Q: 如何添加新的主题颜色？
A: 在 `variables.css` 中的 `:root` 和 `:root[data-theme="dark"]` 中添加新变量。

### Q: 如何自定义响应式断点？
A: 在 `responsive.css` 中修改或添加新的 `@media` 查询。

### Q: 如何禁用主题切换动画？
A: 在组件中覆盖 CSS 变量：
```css
<style scoped>
.my-component {
  transition: none !important;
}
</style>
```

### Q: 如何让某个组件始终使用深色模式？
A: 直接设置深色模式的值：
```css
<style scoped>
.my-component {
  background: #1a1a1a;  /* 深色模式背景 */
  color: #f0f0f0;       /* 深色模式文字 */
}
</style>
```

## 资源链接

- [项目完整文档](./DARK-MODE-RESPONSIVE-IMPLEMENTATION.md)
- [WCAG 可访问性指南](https://www.w3.org/WAI/WCAG21/quickref/)
- [MDN CSS 变量](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties)
- [Material Design 颜色指南](https://material.io/design/color)

## 更新日志

### v1.0.0 (2024-01-11)
- ✅ 完整的深色模式系统
- ✅ 响应式断点系统
- ✅ 移动端优化
- ✅ 完整的可访问性支持
- ✅ 性能优化

---

如有问题或建议，请提交 Issue 或 PR。
