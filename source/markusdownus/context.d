module markusdownus.context;

import markusdownus;

struct MarkdownParseContext(AstT)
{
    CharReader chars;
    AstT.Container[] containerStack;
    WhiteInfo lineWhite;
    MarkdownParagraphLeaf paragraph;

    this(bool _)
    {
        this.containerStack ~= AstT.Container(MarkdownRootContainer());
        this.peek().priority = uint.max;
    }

    void push(ContainerT)(ContainerT container, uint minIndent, uint priority, AstT.TryToCloseFunc toClose)
    {
        this.pushParagraphIfNeeded();
        auto c = AstT.Container(container);
        c.minIndent = minIndent;
        c.tryToClose = toClose;
        c.priority = priority;

        while(this.peek().priority < priority)
            this.popForceClose();

        this.containerStack ~= c;
    }

    void finaliseBlockPass()
    {
        while(this.containerStack.length > 1)
            this.popForceClose();
        this.pushParagraphIfNeeded();
    }

    void appendToParagraph(string line)
    {
        this.paragraph.lines ~= line;
    }

    void pushParagraphIfNeeded()
    {
        if(this.paragraph != MarkdownParagraphLeaf.init)
        {
            this.push!(typeof(this.paragraph), true)(this.paragraph, 0);
            this.paragraph = MarkdownParagraphLeaf.init;
        }
    }

    void push(LeafT, bool isPara = false)(LeafT leaf, uint priority)
    {
        static if(!isPara)
            this.pushParagraphIfNeeded();
        auto l = AstT.Leaf(leaf);
        l.priority = priority;
        while(this.peek().priority < priority)
            this.popForceClose();
        this.peek().children ~= AstT.LeafOrContainer(l);
    }

    void pop()
    {
        this.pushParagraphIfNeeded();
        auto c = this.peek();
        this.containerStack.length--;
        this.peek().children ~= AstT.LeafOrContainer(c);
    }

    void popForceClose()
    {
        this.peek().tryToClose(this, this.peek(), true);
    }

    ref auto peek()
    {
        return this.containerStack[$-1];
    }

    ref auto root()
    {
        return this.containerStack[0];
    }
}