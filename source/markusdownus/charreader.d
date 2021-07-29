module markusdownus.charreader;

import std.typecons : Flag;
import markusdownus._search;

alias IgnoreWhite = Flag!"ignoreWhite";
alias IgnoreEscaped = Flag!"ignoreEscaped";

struct WhiteInfo
{
    uint spaces;

    uint reduceSpaces(uint amount)
    {
        if(amount > spaces)
            amount = spaces;
        return spaces - amount;
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

    bool isRestOfLineEmpty(ref size_t newLineChar)
    {
        const start = this._cursor;
        scope(exit) this._cursor = start;
        while(true)
        {
            if(this.eof || this.peek() == '\n')
            {
                newLineChar = this._cursor;
                return true;
            }

            if(!this.peek.isInlineWhite)
                return false;

            this.advance(1);
        }
    }

    bool eatUntil(char ch, out string text)
    {
        const start = this._cursor;
        const result = indexOfAscii(this._input[this._cursor..$], ch);
        if(result == INDEX_NOT_FOUND)
        {
            this._cursor = this.length;
            return false;
        }

        this._cursor += result;
        text = this._input[start..start+result];
        return true;
    }

    // DRY this eventually.
    bool eatUntilOrEndOfLine(char ch, out string text, out bool wasNewLine)
    {
        const start = this._cursor;
        const result = indexOfAsciiOrEndOfLine(this._input[this._cursor..$], ch, wasNewLine);
        if(result == INDEX_NOT_FOUND)
        {
            this._cursor = this.length;
            return false;
        }

        this._cursor += result;
        text = this._input[start..start+result];
        return true;
    }

    @safe @nogc
    WhiteInfo eatInlineWhite() nothrow
    {
        WhiteInfo info;

        while(!this.eof)
        {
            const next = this.peek();
            if(next == ' ')
                info.spaces++;
            else if(next == '\t')
                info.spaces += 4;
            else
                break;
            this.advance(1);
        }

        return info;
    }

    @safe @nogc
    void eatLine(out size_t endOfLine) nothrow
    {
        const result = indexOfAscii(this._input[this._cursor..$], '\n');
        if(result == INDEX_NOT_FOUND)
        {
            this._cursor = this._input.length;
            endOfLine = this._input.length;
        }
        else
        {
            this._cursor += result + 1;
            endOfLine = this._cursor - 1;
        }
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

    @safe @nogc
    bool atEndOfLine(size_t offset = 0) nothrow const
    {
        return this.eof(offset) || this.peek(offset) == '\n' || this.peek(offset) == '\r';
    }

    @safe @nogc
    bool atStartOfLine() nothrow const
    {
        size_t offset = this._cursor;
        while(offset > 0)
        {
            if(this.at(offset-1) == '\n')
                return true;
            else if(!this.at(offset-1).isInlineWhite())
                return false;
            offset--;
        }
        return true;
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
bool isInlineWhite(char ch) nothrow pure
{
    return ch == ' ' || ch == '\t';
}