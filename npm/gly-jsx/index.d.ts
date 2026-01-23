declare namespace JSX {
  const __gly_jsx: unique symbol;

  type Element = {
    readonly [__gly_jsx]: keyof IntrinsicElements;
  };

  interface IntrinsicElements {
    grid: { class: string, span?: number, offset?: number, after?: number, style?: string, dir?: 1 | 0, children?: JSX.Element | Array<JSX.Element> };
    item: ({ span: number } | { offset: number } | { after: number} | { style: string }) & { children: JSX.Element }
    node: { children?: JSX.Element | Array<JSX.Element> } | { [key: string]: Function; };
    style: { class: string, children?: never } | { [key: string]: number };
  }

  interface ElementChildrenAttribute {
    children: {};
  }
}
