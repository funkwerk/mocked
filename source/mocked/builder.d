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

    ref T get() @nogc nothrow pure @safe
    {
        return this.mock;
    }

    /**
     * Verifies that certain expectation requirements were satisfied.
     *
     * Throws: $(D_PSYMBOL ExpectationViolationException) if those issues occur.
     */
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
            return get().toHash();
        }

        override string toString()
        {
            return get().toString();
        }

        override int opCmp(Object o)
        {
            return get().opCmp(o);
        }

        override bool opEquals(Object o)
        {
            return get().opEquals(o);
        }
    }

    alias get this;
}

/**
 * $(D_PSYMBOL Call) represents a single call of a mocked method.
 *
 * Params:
 *     F = Function represented by this $(D_PSYMBOL Call).
 */
struct Call(alias F)
{
    /// Return type of the mocked method.
    alias Return = ReturnType!F;

    // Parameters accepted by the mocked method.
    alias ParameterTypes = .Parameters!F;

    static if (is(FunctionTypeOf!F PT == __parameters))
    {
        /// Arguments passed to set the expectation up.
        alias Parameters = PT;
    }
    else
    {
        static assert(false, typeof(T).stringof ~ " is not a function");
    }

    /// Attribute set of the mocked method.
    alias qualifiers = AliasSeq!(__traits(getFunctionAttributes, F));

    private alias concatenatedQualifiers = unwords!qualifiers;

    mixin("alias CustomArgsComparator = bool delegate(ParameterTypes) "
            ~ concatenatedQualifiers ~ ";");
    mixin("alias Action = Return delegate(ParameterTypes) "
            ~ concatenatedQualifiers ~ ";");

    bool passThrough_ = false;
    bool ignoreArgs_ = false;
    uint repeat_ = 1;
    Exception exception;
    CustomArgsComparator customArgsComparator_;
    Action action_;

    /// Expected arguments if any.
    alias Arguments = Maybe!ParameterTypes;

    /// ditto
    Arguments arguments;

    static if (!is(Return == void))
    {
        Return return_ = Return.init;

        /**
         * Set the value to return when method matching this expectation is called on a mock object.
         *
         * Params:
         *     value = the value to return
         *
         * Returns: $(D_KEYWORD this).
         */
        public ref typeof(this) returns(Return value)
        {
            this.return_ = value;

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

    /**
     * This expectation will match to any number of calls.
     *
     * Returns: $(D_KEYWORD this).
     */
    public ref typeof(this) repeatAny()
    {
        this.repeat_ = 0;

        return this;
    }

    /**
     * This expectation will match exactly $(D_PARAM times) times.
     *
     * Preconditions:
     *
     * $(D_CODE times > 0).
     *
     * Params:
     *     times = The number of calls the expectation will match.
     *
     * Returns: $(D_KEYWORD this).
     */
    public ref typeof(this) repeat(uint times)
    in (times > 0)
    {
        this.repeat_ = times;

        return this;
    }

    public bool compareArguments(alias options)(ParameterTypes arguments)
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

    /**
     * Allow providing custom argument comparator for matching calls to this expectation.
     *
     * Params:
     *     comaprator = The functions used to compare the arguments.
     *
     * Returns: $(D_KEYWORD this).
     */
    deprecated("Use mocked.Comparator instead")
    public ref typeof(this) customArgsComparator(CustomArgsComparator comparator)
    in (comparator !is null)
    {
        this.customArgsComparator_ = comparator;

        return this;
    }

    /**
     * When the method which matches this expectation is called, throw the given
     * exception. If there are any actions specified (via the action method),
     * they will not be executed.
     *
     * Params:
     *     exception = The exception to throw.
     *
     * Returns: $(D_KEYWORD this).
     */
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
 *     F = Function to build this $(D_PSYMBOL Overload) from.
 */
struct Overload(alias F)
{
    /// Single mocked method call.
    alias Call = .Call!F;

    /// Return type of the mocked method.
    alias Return = Call.Return;

    // Parameters accepted by the mocked method.
    alias ParameterTypes = Call.ParameterTypes;

    /// Arguments passed to set the expectation up.
    alias Parameters = Call.Parameters;

    /// Attribute set of the mocked method.
    alias qualifiers = Call.qualifiers;

    /// Expected arguments if any.
    alias Arguments = Call.Arguments;

    /// Expected calls.
    Call[] calls;

    /**
     * Returns: Whether any expected calls are in the queue.
     */
    public @property bool empty()
    {
        return this.calls.empty;
    }

    /**
     * Returns: The next expected call.
     */
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

    /**
      * Removes the next expected call from the queue.
      */
    public void popFront()
    {
        this.calls.popFront;
    }

    public void popBack()
    {
        this.calls.popBack;
    }

    /**
     * Clears the queue.
     */
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

    static foreach (i, Overload; overloads)
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

        ref Overload.Call opCall(Overload.Parameters arguments)
        {
            typeof(return) call;

            call.arguments = arguments;
            Overload.calls ~= call;

            return Overload.back;
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
