type CSSUnit = `${number}px` | `${number}%` | `${number}vw` | `${number}vh` | number;

type FocusState = '' | ':focus';

declare namespace JSX {
  const __gly_jsx: unique symbol;
  type Element = {
    readonly [__gly_jsx]: keyof IntrinsicElements;
  };
  interface IntrinsicElements {
    grid: {
      class: string,
      span?: number | `${number}x${number}`,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      children?: JSX.Element | Array<JSX.Element>
    };
    slide: {
      class: string,
      id?: string,
      span?: number,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      scroll?: 'shift' | 'page',
      focus?: 'wrap' | 'stop' | 'escape',
      children?: JSX.Element | Array<JSX.Element>
    };
    item: (
      { span?: number | `${number}x${number}` }
      & { offset?: number }
      & { after?: number }
      & { style?: string }
    ) & { children: JSX.Element };
    // <node> follows strict pattern: either children, or all-function attributes.
    // Never mix non-function attributes with callbacks in the same node.
    // Non-function attributes (custom data) go into node.data via loadgame,
    // not as direct JSX attributes.
    node:
      // Children mode: container node with JSX children
      | { children?: JSX.Element | Array<JSX.Element> }
      // Callback mode: all attributes are functions → node.callbacks.*
      | {
          // Engine callbacks
          draw?:    (self: object, std: object) => void,
          loop?:    (self: object, std: object) => void,
          init?:    (self: object, std: object) => void,
          resize?:  (self: object, std: object) => void,
          // Interaction callbacks (any of these → focusable = true implicitly)
          focus?:   (self: object, std: object) => void,
          unfocus?: (self: object, std: object) => void,
          click?:   (self: object, std: object) => void,
          hover?:   (self: object, std: object) => void,
          unhover?: (self: object, std: object) => void,
          // Custom callbacks (any additional function attribute)
          [key: string]: Function,
        };
    // <style> follows strict pattern: either named (with class), or anonymous (all CSSUnit).
    style:
      // Named mode: define/update a stylesheet class
      | { class: `${string}${FocusState}`, children?: never }
      // Named with child: apply named style to a child node
      | { class: `${string}${FocusState}`, children: JSX.Element }
      // Anonymous mode: all attributes are CSSUnit → implicit name from sorted keys
      | {
          width?:  CSSUnit,
          height?: CSSUnit,
          left?:   CSSUnit,
          right?:  CSSUnit,
          top?:    CSSUnit,
          bottom?: CSSUnit,
          margin?: CSSUnit,
          children: JSX.Element,   // required in anonymous mode
          [key: string]: CSSUnit | JSX.Element,
        };
  }
  interface ElementChildrenAttribute {
    children: {};
  }
}
