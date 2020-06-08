module mocked.builder;

import mocked.error;
import mocked.meta;
import std.array;
import std.format;
import std.meta;
import std.traits;

interface Verifiable
{
    void verify();
}

final class Mocked(T) : Verifiable
{
    T mock;
    Repository!T* repository;

    this(T mock, ref Repository!T repository)
    {
        this.mock = mock;
        this.repository = &repository;
    }

    ref Repository!T expect()
    {
        return *this.repository;
    }

    ref T getMock() @nogc nothrow pure @safe
    {
        return this.mock;
    }

    void verify()
    {
        scope (failure)
        {
            static foreach (expectation; this.repository.ExpectationTuple)
            {
                static foreach (i, Overload; expectation.Overloads)
                {
                    __traits(getMember, repository, expectation.name).overloads[i].clear();
                }
            }
        }

        static foreach (expectation; this.repository.ExpectationTuple)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                if (!__traits(getMember, this.repository, expectation.name).overloads[i].empty
                        && __traits(getMember, this.repository, expectation.name).overloads[i].front.repeat_ > 0)
                {
                    throw expectationViolationException!T(expectation.name,
                            __traits(getMember, this.repository, expectation.name).overloads[i].front.arguments);
                }
            }
        }
    }

    static if (is(T == class))
    {
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
    }

    alias getMock this;
}

/**
 * $(D_SYMBOL Call) represents a single call of a mocked method.
 *
 * Params:
 *     R = Return type.
 *     Args = Argument types.
 */
struct Call(R, Args...)
{
    alias Return = R;
    alias Arguments = staticMap!(Unqual, Args);
    alias CustomArgsComparator = bool delegate(Args) pure @nogc nothrow @safe;
    alias Action = Return delegate(Args) pure @nogc nothrow @safe;

    bool passThrough_ = false;
    bool ignoreArgs_ = false;
    uint repeat_ = 1;
    Exception exception;
    CustomArgsComparator customArgsComparator_;
    Action action_;

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

    /**
     * Instead of returning or throwing a given value, pass the call through to
     * the mocked type object.
     *
     * This is useful for example for enabling use of mock object in hashmaps
     * by enabling `toHash` and `opEquals` of your class.
     *
     * Returns: $(D_KEYWORD this).
     */
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

    public bool compareArguments(alias options)(Args arguments)
    {
        if (this.customArgsComparator_ !is null)
        {
            return this.customArgsComparator_(arguments);
        }
        static foreach (i, argument; arguments)
        {
            if (!this.arguments.isNull && !options.equal(this.arguments.get!i, argument))
            {
                return false;
            }
        }
        return true;
    }

    public ref typeof(this) customArgsComparator(CustomArgsComparator comparator)
    in (comparator !is null)
    {
        this.customArgsComparator_ = comparator;

        return this;
    }

    public ref typeof(this) throws(Exception exception)
    {
        this.exception = exception;

        return this;
    }

    /**
     * When the method which matches this expectation is called execute the
     * given delegate. The delegate's signature must match the signature
     * of the called method.
     *
     * The called method will return whatever the given delegate returns.
     *
     * Params:
     *     callback = Callable should be called.
     *
     * Returns: $(D_KEYWORD this).
     */
    public ref typeof(this) action(Action callback)
    {
        this.action_ = callback;

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

    alias qualifiers = AliasSeq!(__traits(getFunctionAttributes, F));

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

    public void clear()
    {
        this.calls = [];
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
if (isPolymorphicType!T)
{
    private alias VirtualMethods = Filter!(ApplyLeft!(isVirtualMethod, T), __traits(allMembers, T));

    alias ExpectationTuple = staticMap!(ApplyLeft!(ExpectationSetup, T), VirtualMethods);

    static foreach (i, member; VirtualMethods)
    {
        mixin("ExpectationTuple[i] " ~ member ~ ";");
    }
}

private enum isVirtualMethod(T, string member) = __traits(isVirtualMethod, __traits(getMember, T, member));
