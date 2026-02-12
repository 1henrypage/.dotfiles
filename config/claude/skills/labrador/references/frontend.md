# Frontend (ChihuahUI) Reference

ChihuahUI is the shared UI component library for the Labrador ecosystem. It provides reusable, accessible components consumed by all Labrador apps (Queue, TAM, GitBull, etc.) via their Thymeleaf templates.

**Repo**: `gitlab.ewi.tudelft.nl/eip/labrador/frontend`
**Docs**: `https://eip.pages.ewi.tudelft.nl/labrador/frontend`

## Component Inventory

### Control Components

#### Button
```html
<button data-type="primary" data-style="filled" class="button">Submit</button>
```
- **`data-type`**: `primary` (default), `error` (destructive actions), `accept` (approval actions)
- **`data-style`**: `filled` (default, primary actions), `outlined` (secondary/cancel actions)
- **Utility classes**: `.p-less` (reduced padding), `.p-min` (minimal padding)

#### Link
```html
<a href="/path" class="link">Link text</a>
```

#### Menu
```html
<div class="menu-wrapper">
    <button aria-haspopup="menu" aria-controls="menu-id">Open menu</button>
    <ul class="menu" id="menu-id" role="menu">
        <li><button role="menuitem" tabindex="-1" class="p-3">Item 1</button></li>
        <li><button role="menuitem" tabindex="-1" class="p-3">Item 2</button></li>
    </ul>
</div>
```
- Arrow key navigation with wraparound, Home/End, Escape to close.

#### Search
```html
<div class="search">
    <input placeholder="Search..." type="search"/>
    <button class="fa-solid fa-search"></button>
</div>
```
- Add `role="search"` to form. Multiple search bars need `aria-label` or `aria-labelledby`.

#### Tabs
```html
<div class="tabs" role="tablist">
    <button role="tab" aria-controls="panel-1" aria-selected="true">Tab 1</button>
    <button role="tab" aria-controls="panel-2" aria-selected="false">Tab 2</button>
</div>
<div id="panel-1" aria-labelledby="tab-1">Content 1</div>
<div id="panel-2" aria-labelledby="tab-2" hidden>Content 2</div>
```

#### Toggle
```html
<div class="flex align-center gap-2">
    <button id="toggle" class="toggle" aria-checked="false" role="switch"></button>
    <label for="toggle">Toggle label</label>
</div>
```
- For instant on/off toggling of page state. For boolean form input, use Checkbox instead.

### Form Components

#### Checkbox
```html
<div>
    <input id="checkbox" type="checkbox"/>
    <label for="checkbox">Checkbox label</label>
</div>
```
- For boolean form data. For toggling page state, use Toggle instead.

#### Selectbox
Currently WIP. **Use a regular `<select>` with `class="textfield"` for now.**
```html
<select class="textfield">
    <option>Option 1</option>
    <option>Option 2</option>
</select>
```

#### Textfield
```html
<input type="text" class="textfield"/>
```
- Must have an associated `<label>`.

### Communication Components

#### Banner
```html
<div class="banner" data-type="info" role="banner">
    <span class="banner__icon fa-solid fa-info-circle"></span>
    <p>Informational message here.</p>
</div>
```
- **`data-type`**: `primary` (default), `error`, `accept`, `warning`, `info`
- Choose a Font Awesome icon matching the banner type.

#### Chip
```html
<div class="chip" data-type="info">
    <span class="fa-solid fa-circle-info"></span>
    <span>Info</span>
</div>
```
- **`data-type`**: `primary` (default), `error`, `accept`, `warning`, `info`
- Used to indicate state of another component.

#### Toast
```javascript
toast("Message text", "info");
```
- **Types**: (default), `error`, `accept`, `warning`, `info`
- Time-sensitive notifications that auto-dismiss. Use Banner for persistent messages.

## Utility Classes

Observed across components (Tailwind-like utilities):
- Layout: `.flex`, `.align-center`, `.gap-2`
- Padding: `.p-3`, `.p-less`, `.p-min`

## Icons

ChihuahUI uses **Font Awesome** (`fa-solid fa-*`) for icons throughout components.

## Integration with Labrador Apps

Labrador apps use server-side rendered Thymeleaf templates. The ChihuahUI library provides the shared assets (CSS, JS, components) that these templates consume. When modifying UI in any Labrador app, check whether the component comes from ChihuahUI before creating custom markup.

### Dependency Pattern
Each Labrador app pulls in ChihuahUI as a dependency. Changes to ChihuahUI affect all consuming apps — test across the suite when making breaking changes.

## Common Tasks

### Modifying a Shared Component
1. Make the change in the Frontend repo
2. Verify the component renders correctly in isolation
3. Test in at least one consuming app (e.g. Queue or TAM)
4. Coordinate releases — consuming apps may need a version bump

### Adding a New Component
1. Create the component in Frontend following existing conventions
2. Document its usage and props/parameters
3. Publish a new version
4. Import and use in the target Labrador app's Thymeleaf templates
