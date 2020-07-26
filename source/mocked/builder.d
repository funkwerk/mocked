module mocked.builder;

import mocked.error;
import mocked.meta;
import std.algorithm.searching;
import std.array;
import std.format;
import std.meta;
import std.traits;

/**
 * Used to save heterogeneous repositories in a single container and verify
 * their expectations at the end.
 */
interface Verifiable
{
    /**
     * Verifies that certain expectation requirements were satisfied.
     *
     * Throws: $(D_PSYMBOL ExpectationViolationException) if those issues occur.
     */
    void verify();
}

/**
 * Mock builder.
 *
 * Params:
 *     T = Mocked type.
 */
final class Mocked(MockT) : Builder!MockT, Verifiable
{
    /**
     * Params:
     *     mock = Mocked object.
     */
    this(MockT mock)
    {
        this.mock = mock;
    }

    /**
     * Returns: Repository used to set up expectations.
     */
    ref auto expect()
    {
        return this.mock.expectationSetup;
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
            static foreach (i, expectation; this.mock.expectationSetup.expectationTuple.Methods)
            {
                static foreach (j, Overload; expectation.Overloads)
                {
                    this.expect.expectationTuple.methods[i].overloads[j].clear();
                }
            }
        }

        static foreach (i, expectation; this.mock.expectationSetup.expectationTuple.Methods)
        {
            static foreach (j, Overload; expectation.Overloads)
            {
                if (!this.expect.expectationTuple.methods[i].overloads[j].empty
                        && this.expect.expectationTuple.methods[i].overloads[j].front.repeat_ > 0)
                {
                    throw expectationViolationException!T(expectation.name,
                            this.expect.expectationTuple.methods[i].overloads[j].front.arguments);
                }
            }
        }
    }

    /**
     * Exepct calls to different mock methods in the given order.
     *
     * Returns: $(D_KEYWORD this).
     */
    public typeof(this) ordered()
    {
        this.mock.expectationSetup.expectationTuple.ordered = true;
        return this;
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
    size_t index = 0;
    uint repeat_ = 1;
    Exception exception;
    CustomArgsComparator customArgsComparator_;
    Action action_;

    @disable this();

    /**
     * Params:
     *     index = Call is expected to be at position $(D_PARAM index) among all
     *             calls on the given mock.
     */
    public this(size_t index)
    {
        this.index = index;
    }

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

    public bool compareArguments(Options)(ParameterTypes arguments)
    {
        Options options;

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
     * Creates an exception of type $(D_PARAM E) and throws it when the method
     * which matches this expectation is called.
     *
     * Params:
     *     E = Exception type to throw.
     *     msg = The error message to put in the exception if it is thrown.
     *     file = The source file of the caller.
     *     line = The line number of the caller.
     *
     * Returns: $(D_KEYWORD this).
     */
    public ref typeof(this) throws(E : Exception = Exception)(
            string msg,
            string file = __FILE__, size_t line = __LINE__)
    {
        this.exception = new E(msg, file, line);

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
 * Function overload representation.
 *
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

    private enum bool isVirtualMethod(alias F) = __traits(isVirtualMethod, F);
    private alias VirtualMethods = Filter!(isVirtualMethod, __traits(getOverloads, T, member));
    alias Overloads = staticMap!(Overload, VirtualMethods);

    Overloads overloads;
}

/**
 * $(D_PSYMBOL Repository) contains all mocked methods of a single class.
 *
 * Params:
 *     T = Mocked type.
 */
template Repository(T)
if (isPolymorphicType!T)
{
    private enum isVirtualMethod(string member) =
        __traits(isVirtualMethod, __traits(getMember, T, member));
    private alias allMembers = __traits(allMembers, T);
    private alias VirtualMethods = Filter!(isVirtualMethod, allMembers);

    struct Configuration
    {
        alias Methods = staticMap!(ApplyLeft!(ExpectationSetup, T), VirtualMethods);

        Methods methods;
        private size_t lastCall_;
        public size_t actualCall;
        bool ordered;

        public @property size_t lastCall()
        {
            return ++this.lastCall_;
        }
    }

    struct Repository
    {
        Configuration expectationTuple;

        static foreach (i, member; VirtualMethods)
        {
            static foreach (j, overload; Configuration.Methods[i].Overloads)
            {
                mixin(format!repositoryProperty(member, i, j));
            }

            static if (!anySatisfy!(hasNoArguments, Configuration.Methods[i].Overloads))
            {
                mixin(format!repositoryProperty0(member, i));
            }
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
            enum ptrdiff_t index = matchArguments!(Pack!Args, Configuration.Methods[%2$s].Overloads);
        }
        static assert(index >= 0,
                "%1$s overload with the given argument types could not be found");

        this.expectationTuple.methods[%2$s].overloads[index].calls ~=
            Configuration.Methods[%2$s].Overloads[index].Call(this.expectationTuple.lastCall);
        return this.expectationTuple.methods[%2$s].overloads[index].back;
    }
};

private enum string repositoryProperty = q{
    ref auto %1$s(overload.Parameters arguments)
    {
        this.expectationTuple.methods[%2$s].overloads[%3$s].calls ~=
            overload.Call(this.expectationTuple.lastCall);
        this.expectationTuple.methods[%2$s].overloads[%3$s].back.arguments = arguments;
        return this.expectationTuple.methods[%2$s].overloads[%3$s].back;
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

/**
 * Mock builder used by the mocks and stubs.
 *
 * Params:
 *     T = Mocked type.
 */
abstract class Builder(MockT)
{
    private alias T = TemplateArgsOf!MockT[0];

    /// Mocked object instance.
    protected MockT mock;

    invariant(mock !is null);

    /**
     * Returns: Mocked object.
     */
    T get() @nogc nothrow pure @safe
    {
        return this.mock;
    }

    static if (is(T == class))
    {
        /**
         * Forward default object methods to the mock.
         */
        override size_t toHash()
        {
            return get().toHash();
        }

        /// ditto
        override string toString()
        {
            return get().toString();
        }

        /// ditto
        override int opCmp(Object o)
        {
            return get().opCmp(o);
        }

        /// ditto
        override bool opEquals(Object o)
        {
            return get().opEquals(o);
        }
    }
}

final class Mock(T, Options, string overloadingCode, Args...) : T
{
    import std.string : join;

    Repository!T expectationSetup;

    static if (__traits(hasMember, T, "__ctor") && Args.length > 0)
    {
        this(ref Args args)
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

    static foreach (j, expectation; expectationSetup.expectationTuple.Methods)
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
