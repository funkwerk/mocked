module mocked.rt;

import mocked.builder;
import std.conv;
import std.traits;

struct MockRepository(T)
{
    T mock;
    Builder!T* builder;

    @disable this();

    this(T mock, ref Builder!T builder)
    {
        this.mock = mock;
        this.builder = &builder;
    }

    ref Builder!T expect()
    {
        return *this.builder;
    }

    ref T getMock()
    {
        return this.mock;
    }

    alias getMock this;
}
