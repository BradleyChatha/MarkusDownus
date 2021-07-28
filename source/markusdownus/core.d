module markusdownus.core;

import std.meta : AliasSeq, NoDuplicates;
import taggedalgebraic.taggedunion;
import markusdownus.syntax1, markusdownus.syntax2, markusdownus.charreader;

alias MARKDOWN_DEFAULT_SYNTAX1 = AliasSeq!(
    HeaderParser,
    BlankLineParser,
    IndentedCodeParser,
    FencedCodeParser,
    ThematicBreakParser,
    SetextHeaderParser,
    ParagraphLineParser,
    QuoteParser,
    ListItemParser
);

alias MARKDOWN_DEFAULT_SYNTAX2 = AliasSeq!(
    CodeParser,
    EmphesisParser,
    LinkParser
);

alias MarkdownDefault = Markdown!(
    MarkdownSyntax1!MARKDOWN_DEFAULT_SYNTAX1,
    MarkdownSyntax2!MARKDOWN_DEFAULT_SYNTAX2
);

struct MarkdownSyntax1Parser
{
    dchar triggerChar;
    uint spacePrefixLimit = SYNTAX1_DEFAULT_ALLOWED_WHITE_PREFIX_LIMIT;
}

struct MarkdownSyntax2Parser
{
    dchar triggerChar;
    bool wantsWhiteBefore;
}

struct MarkdownSyntax1(Parsers_...)
{
    alias Parsers = Parsers_;
}
struct MarkdownSyntax2(Parsers_...)
{
    alias Parsers = Parsers_;
}

enum MarkdownSyntax1Result
{
    FAILSAFE,
    foundContainerBlock,
    foundLeafBlock,
    didNothing
}

enum MarkdownSyntax2Result
{
    FAILSAFE,
    foundInline,
    didNothing
}

@MarkdownContainerBlock("junk")
struct JunkContainerBlock
{
    MarkdownTextRange range;
    string message;
}

@MarkdownLeafBlock("junk")
struct JunkLeafBlock
{
    MarkdownTextRange range;
    string message;
}

@MarkdownInline("junk")
struct JunkInline
{
    MarkdownTextRange range;
    string message;
}

@MarkdownInline("plain")
struct PlainTextInline
{
    MarkdownTextRange range;
}

@MarkdownContainerBlock("root")
struct RootContainerBlock
{
}

struct MarkdownTextRange
{
    size_t start;
    size_t end;
    string text;
}

struct MarkdownLeafBlock
{
    string varName;
}

struct MarkdownContainerBlock
{
    string varName;
}

struct MarkdownInline
{
    string varName;
}

union MarkdownUnion(Types...)
{
    import std.traits : getUDAs;
    static foreach(i, type; Types)
    {
        static if(getUDAs!(type, MarkdownLeafBlock).length)
            mixin("type "~getUDAs!(type, MarkdownLeafBlock)[0].varName~";");
        else static if(getUDAs!(type, MarkdownInline).length)
            mixin("type "~getUDAs!(type, MarkdownInline)[0].varName~";");
        else
            mixin("type "~getUDAs!(type, MarkdownContainerBlock)[0].varName~";");
    }
}

struct Markdown(Syntax1, Syntax2)
{
    alias Syntax1Parsers = Syntax1.Parsers;
    alias Syntax2Parsers = Syntax2.Parsers;
    Syntax1Parsers syntax1Instances;

    // Who knew a statically typed AST provided dynamically from arbitrary user types would be messy?
    // btw I've already lost how any of this is working. Good luck future me.
    alias LeafBlocks = NoDuplicates!(AliasSeq!(
        GatherTypes!("LeafBlocks", Syntax1.Parsers), 
        JunkLeafBlock
    ));
    alias ContainerBlocks = NoDuplicates!(AliasSeq!(
        GatherTypes!("ContainerBlocks", Syntax1.Parsers), 
        JunkContainerBlock, 
        RootContainerBlock
    ));
    alias Inlines = NoDuplicates!(AliasSeq!(
        GatherTypes!("Inlines", Syntax2.Parsers),
        JunkInline,
        PlainTextInline
    ));
    alias Blocks = AliasSeq!(
        LeafBlocks, 
        ContainerBlocks
    );

    alias LeafBlockUnionTT      = MarkdownUnion!LeafBlocks;
    alias ContainerBlockUnionTT = MarkdownUnion!ContainerBlocks;
    alias InlineUnionTT         = MarkdownUnion!Inlines;
    alias LeafBlockUnionT       = TaggedUnion!LeafBlockUnionTT;
    alias ContainerBlockUnionT  = TaggedUnion!ContainerBlockUnionTT;
    alias InlineUnionT          = TaggedUnion!InlineUnionTT;
    
    static struct InlineUnion
    {
        InlineUnionT value;

        this(T)(T value)
        {
            this.value = value;
        }

        @safe @nogc
        bool isType(Type)() nothrow const
        {
            return this.value.hasType!Type;
        }
    }

    static struct LeafBlockUnion
    {
        LeafBlockUnionT value;
        InlineUnion[] inlines;

        this(T)(T value)
        {
            this.value = value;
        }
    }

    static struct ContainerBlockUnion
    {
        ContainerBlockUnionT value;
        BlockUnion[] children;

        this(T)(T value)
        {
            this.value = value;
        }

        void addChild(LeafBlockUnion leaf)
        {
            this.children ~= BlockUnion(leaf);
        }

        void addChild(ContainerBlockUnion block)
        {
            this.children ~= BlockUnion(block);
        }

        void addChild(BlockUnion block)
        {
            this.children ~= block;
        }

        bool childIsLeafOfType(alias Type)(size_t childIndex)
        {
            return this.children[childIndex].leafValue.value.hasType!Type;
        }
    }

    static union BlockUnionT
    {
        LeafBlockUnion leaf;
        ContainerBlockUnion container;
    }
    static struct BlockUnion // Have to use my own tagged union in order to solve forward reference issues.
    {
        private enum Type { leaf, container }
        private Type _type;
        private BlockUnionT _value;

        this(ContainerBlockUnion value)
        {
            this._value.container = value;
            this._type = Type.container;
        }

        this(LeafBlockUnion value)
        {
            this._value.leaf = value;
            this._type = Type.leaf;
        }

        @safe @nogc
        bool isContainer() nothrow const
        {
            return this._type == Type.container;
        }

        @trusted @nogc
        ref inout(ContainerBlockUnion) containerValue() nothrow inout
        {
            assert(this.isContainer);
            return this._value.container;
        }

        @safe @nogc
        bool isContainerOfType(Type)() nothrow const
        {
            return this.isContainer && this.containerValue.value.hasType!Type;
        }

        @safe @nogc
        bool isLeaf() nothrow const
        {
            return this._type == Type.leaf;
        }

        @safe @nogc
        bool isLeafOfType(Type)() nothrow const
        {
            return this.isLeaf && this.leafValue.value.hasType!Type;
        }

        @trusted @nogc
        ref inout(LeafBlockUnion) leafValue() nothrow inout
        {
            assert(this.isLeaf);
            return this._value.leaf;
        }
    }

    static Syntax1Context!(typeof(this)) doSyntax1(string input)
    {
        typeof(return) context = typeof(return)("dummy");
        context.chars = CharReader(input);
        syntax1(context);
        return context;
    }

    static Syntax1Context!(typeof(this)) doSyntax2(ref return Syntax1Context!(typeof(this)) context)
    {
        void handleBlock(ref BlockUnion block)
        {
            if(block.isLeaf)
            {
                auto ctx = Syntax2Context!(typeof(this))(block.leafValue);
                syntax2(ctx);
            }
            else
            {
                foreach(ref subblock; block.containerValue.children)
                    handleBlock(subblock);
            }
        }
        foreach(ref block; context.blockStack)
            handleBlock(block);
        return context;
    }

    static Syntax1Context!(typeof(this)) doFullSyntax(string input)
    {
        auto context = doSyntax1(input);
        doSyntax2(context);
        return context;
    }
}

private template GatherTypes(string AliasName, Parsers...)
{
    import std.meta : staticMap, Filter;

    enum HasType(alias Parser) = __traits(hasMember, Parser, AliasName);
    alias GetType(alias Parser) = __traits(getMember, Parser, AliasName);
    alias ParsersWithType = Filter!(HasType, Parsers);
    alias GatherTypes = staticMap!(GetType, ParsersWithType);
}

private template GetEnumFieldName(alias Uda, alias Symbol)
{
    import std.traits : getUDAs;

    enum udas = getUDAs!(Symbol, Uda);
    const GetEnumFieldName = udas[0].varName;
}