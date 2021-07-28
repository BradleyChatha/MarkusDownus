module markusdownus.charreader;

import std.typecons : Flag;

alias IgnoreWhite = Flag!"ignoreWhite";
alias IgnoreEscaped = Flag!"ignoreEscaped";

struct WhiteInfo
{
    size_t spaces;
    size_t tabs;

    bool isIndentedChunk()
    {
        return tabs >= 1 || spaces >= 4;
    }
}

struct CharReader
{
    private string _input;
    private size_t _cursor;

    @safe @nogc nothrow
    this(string input) pure
    {
        this._input = input;
    }

    @safe @nogc
    void advance(size_t amount) nothrow
    {
        assert(this._cursor + amount >= this._cursor);
        this._cursor += amount;
    }

    @safe @nogc
    void retreat(size_t amount) nothrow
    {
        assert(this._cursor - amount <= this._cursor);
        this._cursor -= amount;
    }

    @safe @nogc
    char at(size_t index) nothrow const
    {
        return this._input[index];
    }

    @safe @nogc
    char peek() nothrow const
    {
        return this._input[this._cursor];
    }

    @safe @nogc
    char peek(size_t offset) nothrow const
    {
        return this._input[this._cursor + offset];
    }

    @safe @nogc
    char peekEscaped(out bool wasEscaped, size_t offset = 0) nothrow const
    {
        const first = this.peek(offset);
        if(first != '\\')
            return first;

        wasEscaped = true;
        return this.eof(offset+1) ? '\n' : this.peek(offset+1);
    }

    @safe @nogc
    size_t peekSameChar(IgnoreWhite ignoreWhite = IgnoreWhite.no, IgnoreEscaped ignoreEscaped = IgnoreEscaped.no)(char ch) nothrow const
    {
        size_t count;
        while(!this.eof(count))
        {
            static if(!ignoreEscaped)
            {
                bool wasEscaped;
                const next = this.peekEscaped(wasEscaped, count);
                if(wasEscaped)
                    break;
            }
            else
                const next = this.peek(count);

            static if(!ignoreWhite)
            if(next.isInlineWhite)
                break;
            if(next != ch)
                break;
            count++;
        }
        return count;
    }

    bool eatUntil(char ch, out string text)
    {
        const start = this._cursor;
        while(!this.eof && this.peek() != ch)
            this.advance(1);
        text = this._input[start..this._cursor];
        return !this.eof;
    }

    @safe @nogc
    WhiteInfo eatPrefixWhite() nothrow
    {
        WhiteInfo info;

        while(!this.eof)
        {
            const next = this.peek();
            if(next == ' ')
                info.spaces++;
            else if(next == '\t')
                info.tabs++;
            else
                break;
            this.advance(1);
        }

        return info;
    }

    @safe @nogc
    void eatLine(out size_t endOfLine) nothrow
    {
        while(!this.eof)
        {
            const next = this.peek();
            this.advance(1);

            if(next == '\n')
            {
                endOfLine = this.cursor-1;
                return;
            }
            else if(next == '\r')
            {
                endOfLine = this.cursor-1;
                if(this.peek() == '\n')
                    this.advance(1);
                return;
            }
        }
        endOfLine = this._input.length;
    }

    @safe @nogc
    char[amount] peekMany(size_t amount)() nothrow const
    {
        auto end = this.cursor + amount;
        if(end > this._input.length)
            end = this._input.length;

        char[amount] buffer;
        buffer[0..end-this.cursor] = this._input[this.cursor..end];
        return buffer;
    }

    @safe
    dchar peekUtf(out size_t charsRead) const
    {
        import std.utf : decode;
        auto cursor = this.cursor;
        const result = this._input.decode(cursor);
        charsRead = cursor - this.cursor;
        return result;
    }

    @safe
    dchar peekUtfEscaped(out size_t charsRead, out bool wasEscaped)
    {
        if(this.peek != '\\')
            return this.peekUtf(charsRead);

        this.advance(1);
        wasEscaped = true;
        if(this.eof)
            return '\n';

        const result = this.peekUtf(charsRead);
        charsRead++;
        this.retreat(1);
        return result;
    }

    @safe @nogc
    bool atEndOfLine(size_t offset = 0) nothrow const
    {
        return this.eof(offset) || this.peek(offset) == '\n' || this.peek(offset) == '\r';
    }

    @safe @nogc
    string slice(size_t start, size_t end) nothrow const pure
    {
        return this._input[start..end];
    }

    @property @safe @nogc
    bool eof() nothrow const
    {
        return this._cursor >= this._input.length;
    }

    @property @safe @nogc
    bool eof(size_t offset) nothrow const
    {
        return this._cursor + offset >= this._input.length;
    }

    @property @safe @nogc
    size_t cursor() nothrow const
    {
        return this._cursor;
    }

    @property @safe @nogc
    void cursor(size_t nCursor) nothrow
    {
        this._cursor = nCursor;
    }

    @property @safe @nogc
    size_t length() nothrow const
    {
        return this._input.length;
    }
}

@safe @nogc
private bool isInlineWhite(char ch) nothrow pure
{
    return ch == ' ' || ch == '\t';
}