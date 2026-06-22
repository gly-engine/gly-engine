type SpanUnit = `${number}x${number}`
type CSSUnit = `${number}px` | `${number}%` | `${number}vw` | `${number}vh` | number;

type FocusState = '' | ':focus';

// span and z-index are structural style props: applying a class via
// `style="name"` (or addStyle) drives the node's grid span and draw z-order.
// A declaring style overrides the element's own inline span; z is style-only.
type StyleProps = {
  width?:     CSSUnit,
  height?:    CSSUnit,
  left?:      CSSUnit,
  right?:     CSSUnit,
  top?:       CSSUnit,
  bottom?:    CSSUnit,
  margin?:    CSSUnit,
  span?:      number | SpanUnit,
  'z-index'?: number,
  invisible?: boolean,
};

declare namespace JSX {

  const __gly_jsx: unique symbol;

  type Element = {
    readonly [__gly_jsx]: keyof IntrinsicElements;
  };

  interface IntrinsicElements {
    grid: {
      id?: string,
      class: SpanUnit,
      span?: number | `${number}x${number}`,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      scroll?: 'shift' | 'page' | 'peek',
      focus?: 'wrap' | 'stop' | 'escape',
      children?: JSX.Element | Array<JSX.Element>
    };

    item: (
      & { id?: string }
      & { span?: number | SpanUnit }
      & { offset?: number }
      & { after?: number }
      & { style?: string }
    ) & { children: JSX.Element };

    node:
      | { children?: JSX.Element | Array<JSX.Element> }
      | {[key: string]: Function };

    style:
      | ({ class: `${string}${FocusState}`, children?: never } & StyleProps)
      | ({ class: `${string}${FocusState}`, children: JSX.Element } & StyleProps)
      | ({ children: JSX.Element } & StyleProps);
  }

  interface ElementChildrenAttribute {
    children: {};
  }

}
