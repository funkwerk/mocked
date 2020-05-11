module mocked.builder;

import std.algorithm;
import std.array;
import std.exception;
import std.conv;
import std.traits;
import std.typecons;
import tanya.meta.metafunction;
import tanya.meta.trait : isPolymorphicType;

final class ExpectationViolationError : Error
{
    mixin basicExceptionCtors;
}

struct Maybe(Arguments...)
{
    private Arguments arguments = Arguments.init;
    private bool isNull_ = true;

    public static Maybe!Arguments opCall(Arguments arguments)
    {
        typeof(return) ret;

        ret.arguments = arguments;
        ret.isNull_ = false;

        return ret;
    }

    public void opAssign(Arguments arguments)
    {
        this.arguments = arguments;
        this.isNull_ = false;
    }

    public @property bool isNull()
    {
        return this.isNull_;
    }

    public @property ref Arguments[n] get(size_t n)()
    if (n < Arguments.length)
    in (!this.isNull())
    {
        return this.arguments[n];
    }
}

/**
 * Params:
 *     F = Function to build this $(D_SYMBOL Call) from.
 */
struct Call(R, Args...)
{
    alias Return = R;
    alias Arguments = Args;

    Maybe!Arguments arguments;
    Return return_ = Return.init;

    public ref typeof(this) returns(Return return_)
    {
        this.return_ = return_;

        return this;
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

    alias Overloads = Map!(Overload, __traits(getOverloads, T, member));

    Overloads overloads;

    static foreach (i, Overload; Overloads)
    {
        ref Overload.Call returns(Overload.Return return_)
        {
            typeof(return) call;

            call.returns(return_);
            this.overloads[i].calls ~= call;

            return this.overloads[i].back;
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

template VirtualMethods(T)
{
    private template isVirtualMethod(string member)
    {
        enum bool isVirtualMethod =
            __traits(isVirtualMethod, __traits(getMember, T, member));
    }
    alias VirtualMethods = Filter!(isVirtualMethod, __traits(allMembers, T));
}

struct Builder(T)
if (isPolymorphicType!T)
{
    private alias MemberExpectationSetup = ApplyLeft!(ExpectationSetup, T);
    private alias VirtualMethods = .VirtualMethods!T;

    alias ExpectationTuple = Map!(MemberExpectationSetup, VirtualMethods);

    static foreach (i, member; VirtualMethods)
    {
        mixin("ExpectationTuple[i] " ~ member ~ ";");
    }
}
