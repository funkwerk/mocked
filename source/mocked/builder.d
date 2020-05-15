module mocked.builder;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.meta;
import std.traits;
import std.typecons;

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
    static if (!is(Return == void))
    {
        Return return_ = Return.init;

        public ref typeof(this) returns(Return return_)
        {
            this.return_ = return_;

            return this;
        }
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

struct Builder(T)
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
