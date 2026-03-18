type SpanUnit = `${number}x${number}`
type CSSUnit = `${number}px` | `${number}%` | `${number}vw` | `${number}vh` | number;

type FocusState = '' | ':focus';

declare namespace JSX {

  const __gly_jsx: unique symbol;

  type Element = {
    readonly [__gly_jsx]: keyof IntrinsicElements;
  };

  interface IntrinsicElements {
    grid: {
      class: SpanUnit,
      span?: number | `${number}x${number}`,
      offset?: number,
      after?: number,
      style?: string,
      dir?: 'row' | 'col',
      scroll?: 'shift' | 'page' | 'flow',
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
      | { class: `${string}${FocusState}`, children?: never }
      | { class: `${string}${FocusState}`, children: JSX.Element }
      | {
          width?:  CSSUnit,
          height?: CSSUnit,
          left?:   CSSUnit,
          right?:  CSSUnit,
          top?:    CSSUnit,
          bottom?: CSSUnit,
          margin?: CSSUnit,
          children: JSX.Element,
        };
  }

  interface ElementChildrenAttribute {
    children: {};
  }

}
