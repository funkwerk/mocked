module mocked.repository;

import mocked.builder;
import std.conv;
import std.traits;

class Repository(T)
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

    ref T getMock() @nogc nothrow pure @safe
    {
        return this.mock;
    }

    void verify()
    {
        static foreach (expectation; this.builder.ExpectationTuple)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                if (!__traits(getMember, builder, expectation.name).overloads[i].empty)
                {
                    throw new ExpectationViolationError("Expected method not called");
                }
            }
        }
    }

    override size_t toHash()
    {
        return getMock().toHash();
    }

    override string toString()
    {
        return getMock().toString();
    }

    override int opCmp(Object o)
    {
        return getMock().opCmp(o);
    }

    override bool opEquals(Object o)
    {
        return getMock().opEquals(o);
    }

    alias getMock this;
}