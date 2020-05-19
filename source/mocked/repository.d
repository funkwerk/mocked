module mocked.repository;

import mocked.error;
import mocked.builder;
import mocked.meta;
import std.array;
import std.format;
import std.meta;
import std.traits;

/**
 * Params:
 *     F = Function to build this $(D_SYMBOL Call) from.
 */
struct Call(R, Args...)
{
    alias Return = R;
    alias Arguments = staticMap!(Unqual, Args);

    bool passThrough_ = false;
    bool ignoreArgs_ = false;
    uint repeat_ = 1;

    Maybe!Arguments arguments;
    static if (!is(Return == void))
    {
        Return return_ = Return.init;

        public ref typeof(this) returns(Return return_)
        {
            this.return_ = return_;

            return this;
        }
    }

    public ref typeof(this) passThrough()
    {
        this.passThrough_ = true;

        return this;
    }

    public ref typeof(this) ignoreArgs()
    {
        this.ignoreArgs_ = true;

        return this;
    }

    public ref typeof(this) repeatAny()
    {
        this.repeat_ = 0;

        return this;
    }

    public ref typeof(this) repeat(uint times)
    in (times > 0)
    {
        this.repeat_ = times;

        return this;
    }
}

template words(Args...)
{
    static if (Args.length == 0)
    {
        enum string words = "";
    }
    else static if (Args.length == 1)
    {
        enum string words = Args[0];
    }
    else
    {
        enum string words = format!"%s %s"(Args[0], words!(Args[1..$]));
    }
}

/**
 * Params:
 *     F = Function to build this $(D_SYMBOL Overload) from.
 */
struct Overload(alias F)
{
    alias Return = ReturnType!F;
    alias Arguments = Parameters!F;
    alias ArgumentIdentifiers = ParameterIdentifierTuple!F;
    alias Call = .Call!(Return, Arguments);

    enum string qualifiers = words!(__traits(getFunctionAttributes, F));

    Call[] calls;

    public @property bool empty()
    {
        return this.calls.empty;
    }

    public ref Call front()
    in (!this.calls.empty)
    {
        return this.calls.front;
    }

    public ref Call back()
    in (!this.calls.empty)
    {
        return this.calls.back;
    }

    public void popFront()
    {
        this.calls.popFront;
    }

    public void popBack()
    {
        this.calls.popBack;
    }
}

struct ExpectationSetup(T, string member)
{
    enum string name = member;

    alias Overloads = staticMap!(Overload, __traits(getOverloads, T, member));

    Overloads overloads;

    static foreach (i, Overload; Overloads)
    {
        static if (!is(Overload.Return == void))
        {
            ref Overload.Call returns(Overload.Return return_)
            {
                typeof(return) call;

                call.returns(return_);
                this.overloads[i].calls ~= call;

                return this.overloads[i].back;
            }
        }

        ref Overload.Call opCall(Overload.Arguments arguments)
        {
            typeof(return) call;

            call.arguments = arguments;
            this.overloads[i].calls ~= call;

            return this.overloads[i].back;
        }
    }
}

struct Repository(T)
if (is(T == class) || is(T == interface))
{
    private alias VirtualMethods = Filter!(ApplyLeft!(isVirtualMethod, T), __traits(allMembers, T));

    alias ExpectationTuple = staticMap!(ApplyLeft!(ExpectationSetup, T), VirtualMethods);

    static foreach (i, member; VirtualMethods)
    {
        mixin("ExpectationTuple[i] " ~ member ~ ";");
    }
}

private enum isVirtualMethod(T, string member) = __traits(isVirtualMethod, __traits(getMember, T, member));
