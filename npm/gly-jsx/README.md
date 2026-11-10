# Gly JSX

> Gly JSX is a declarative syntax that compiles to Gly Engine’s own DOM system.
It does not use HTML, browser DOM, or a virtual DOM.

### Create a base element

```jsx
const Text = (attributes: {content: string}, std: GlyStd) => <node
  draw={() => {
    std.draw.color(std.color.white)
    std.text.print(0, 0, attributes.content)
  }}
/>
```

### Create a compound component

```jsx
const Button = (attributes: {label: string}) => <node>
  <Rect backgroundColor={std.color.blue} borderColor={std.color.white}>
  <Text label={attributes.label}>
</node>
```

### Using grid-system to create a complex component

_This example uses ready-made components from [**acai-jsx**](https://www.npmjs.com/package/acai-jsx)._

```jsx
const Card = (attributes: {}, std: GlyStd) => <grid class "5x3">
  <Text span={5}>Title</Text>
  <Image offset={1} after={1} span={3} src='myimage.png'/>
  <TextBlock style="container">Loren ipsum</TextBlock>
  <Button offset={3} label="click"/>
  <Button label="cancel"/>
</grid>
```
