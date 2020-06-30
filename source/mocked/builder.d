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

/**
 * Mock builder.
 *
 * Params:
 *     T = Mocked type.
 */
final class Mocked(T) : Builder!T, Verifiable
{
    /**
     * Params:
     *     mock = Mocked object.
     *     repository = Repository used to set up expectations.
     */
    this(T mock, ref Repository!T repository)
    {
        get = mock;
        this.repository = &repository;
    }

    /**
     * Returns: Repository used to set up expectations.
     */
    ref Repository!T expect()
    {
        return *this.repository;
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
            static foreach (i, expectation; this.repository.ExpectationTuple)
            {
                static foreach (j, Overload; expectation.Overloads)
                {
                    this.repository.expectationTuple[i].overloads[j].clear();
                }
            }
        }

        static foreach (i, expectation; this.repository.ExpectationTuple)
        {
            static foreach (j, Overload; expectation.Overloads)
            {
                if (!this.repository.expectationTuple[i].overloads[j].empty
                        && this.repository.expectationTuple[i].overloads[j].front.repeat_ > 0)
                {
                    throw expectationViolationException!T(expectation.name,
                            this.repository.expectationTuple[i].overloads[j].front.arguments);
                }
            }
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

    private enum concatenatedQualifiers = [qualifiers].join(" ");

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

    deprecated("Just skip the argument setup")
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

    /**
     * Returns: The last expected call.
     */
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

    /**
      * Removes the last expected call from the queue.
      */
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

/**
 * $(D_PSYMBOL ExpectationSetup) contains all overloads of a single method.
 *
 * Params:
 *     T = Mocked type.
 *     member = Mocked method name.
 */
struct ExpectationSetup(T, string member)
{
    enum string name = member;

    alias Overloads = staticMap!(Overload, __traits(getOverloads, T, member));

    Overloads overloads;
}

/**
 * $(D_PSYMBOL Repository) contains all mocked methods of a single class.
 *
 * Params:
 *     T = Mocked type.
 */
struct Repository(T)
if (isPolymorphicType!T)
{
    private alias VirtualMethods = Filter!(ApplyLeft!(isVirtualMethod, T), __traits(allMembers, T));

    alias ExpectationTuple = staticMap!(ApplyLeft!(ExpectationSetup, T), VirtualMethods);
    ExpectationTuple expectationTuple;

    static foreach (i, member; VirtualMethods)
    {
        static foreach (j, overload; ExpectationTuple[i].Overloads)
        {
            mixin(format!repositoryProperty(member, i, j));
        }

        static if (!anySatisfy!(hasNoArguments, ExpectationTuple[i].Overloads))
        {
            mixin(format!repositoryProperty0(member, i));
        }
    }
}

private enum string repositoryProperty0 = q{
    ref auto %1$s(Args...)()
    {
        static if (Args.length == 0)
        {
            enum ptrdiff_t index = 0;
        }
        else
        {
            enum ptrdiff_t index = matchArguments!(Pack!Args, ExpectationTuple[%2$s].Overloads);
        }
        static assert(index >= 0,
                "%1$s overload with the given argument types could not be found");

        this.expectationTuple[%2$s].overloads[index].calls ~=
            ExpectationTuple[%2$s].Overloads[index].Call();
        return this.expectationTuple[%2$s].overloads[index].back;
    }
};

private enum string repositoryProperty = q{
    ref auto %1$s(overload.Parameters arguments)
    {
        this.expectationTuple[%2$s].overloads[%3$s].calls ~= overload.Call();
        this.expectationTuple[%2$s].overloads[%3$s].back.arguments = arguments;
        return this.expectationTuple[%2$s].overloads[%3$s].back;
    }
};

private template matchArguments(Needle, Haystack...)
{
    private template matchArgumentsImpl(ptrdiff_t i, Haystack...)
    {
        static if (Haystack.length == 0)
        {
            enum ptrdiff_t matchArgumentsImpl = -1;
        }
        else static if (__traits(isSame, Needle, Pack!(Haystack[0].ParameterTypes)))
        {
            enum ptrdiff_t matchArgumentsImpl = i;
        }
        else
        {
            enum ptrdiff_t matchArgumentsImpl = matchArgumentsImpl!(i + 1, Haystack[1 .. $]);
        }
    }
    enum ptrdiff_t matchArguments = matchArgumentsImpl!(0, Haystack);
}

private enum bool hasNoArguments(T) = T.Parameters.length == 0;
private enum isVirtualMethod(T, string member) =
    __traits(isVirtualMethod, __traits(getMember, T, member));

/**
 * Mock builder used by the mocks and stubs.
 *
 * Params:
 *     T = Mocked type.
 */
abstract class Builder(T)
{
    private T mock;
    protected Repository!T* repository;

    /**
     * Returns: Mocked object.
     */
    ref T get() @nogc nothrow pure @safe
    {
        return this.mock;
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
}

mixin template NestedMock(string overloadingCode)
{
    class Mock : T
    {
        import std.string : join;

        static if (__traits(hasMember, T, "__ctor") && Args.length > 0)
        {
            this()
            {
                super(args);
            }
        }
        else static if (__traits(hasMember, T, "__ctor"))
        {
            this()
            {
                super(Parameters!(T.__ctor).init);
            }
        }

        static foreach (j, expectation; repository.ExpectationTuple)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                mixin(["override", Overload.qualifiers, "Overload.Return", expectation.name].join(" ") ~ q{
                    (Overload.ParameterTypes arguments)
                    {
                        mixin(overloadingCode);
                    }
                });
            }
        }
    }
}
