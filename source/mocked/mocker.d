module mocked.mocker;

import mocked.error;
import mocked.meta;
import mocked.option;
import std.algorithm;
import std.array;
import std.container.dlist;
import std.conv;
import std.exception;
import std.format : format;
import std.meta;
import std.range : drop;
import std.traits;
import std.typecons;

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

private template findMatchIndex(Options, Call, ExpectationTuple, Arguments...)
{
    alias Pair = Tuple!(size_t, "index", bool, "matched");
    alias T = Nullable!Pair;

    /*
     * This function tries to find the best match for a function with the given
     * arguments. If the expectations are ordered, it can modify the
     * expectation chain; it will remove .repeatAny() calls if it can find a
     * better match after them.
     */
    T findMatchIndex(ref Call[] calls,
            ref ExpectationTuple expectationTuple, ref Arguments arguments,
            size_t startIndex)
    {
        auto withComparedArguments = calls
            .drop(startIndex)
            .map!(call => tuple(call, call.compareArguments!Options(arguments)));

        const relativeIndex = withComparedArguments
            .countUntil!(call => expectationTuple.ordered || call[1]);
        if (relativeIndex == -1)
        {
            return T();
        }
        const size_t absoluteIndex = startIndex + relativeIndex;
        auto matchAtIndex = nullable(Pair(absoluteIndex, withComparedArguments[relativeIndex][1]));
        if (calls[absoluteIndex].repeat_ != 0)
        {
            return matchAtIndex;
        }

        const secondTry = findMatchIndex!(Options, Call, ExpectationTuple, Arguments)(
                calls, expectationTuple, arguments, absoluteIndex + 1);

        if (secondTry.isNull || !secondTry.get.matched)
        {
            return matchAtIndex;
        }
        else if (expectationTuple.ordered)
        {
            ++expectationTuple.actualCall;
            calls = calls.remove(absoluteIndex);

            return T(Pair(secondTry.get.index - 1, secondTry.get.matched));
        }
        else
        {
            return secondTry;
        }
    }
}

private enum string mockCode = q{
    auto expectationTuple = getExpectationTuple(expectationSetup);
    auto overloads = &expectationTuple.methods[j].overloads[i];

    const matchAtIndex = findMatchIndex!Options(overloads.calls,
            expectationTuple, arguments, 0);

    if (matchAtIndex.isNull)
    {
        throw unexpectedCallError!(typeof(super), Overload.ParameterTypes)(expectation.name, arguments);
    }
    expectationTuple.actualCall += matchAtIndex.get.index;
    auto matchedElement = &overloads.calls[matchAtIndex.get.index];

    if (matchedElement.repeat_ > 0 && !matchAtIndex.get.matched)
    {
        auto overloadArguments = matchedElement.arguments;

        overloads.clear();

        throw unexpectedArgumentError!(typeof(super),
                Overload.ParameterTypes, Overload.Arguments)(
                expectation.name, arguments, overloadArguments);
    }

    if (expectationTuple.ordered
            && matchedElement.repeat_ == 1
            && matchedElement.index != ++expectationTuple.actualCall)
    {
        throw outOfOrderCallError!(typeof(super), Overload.ParameterTypes)(
                    expectation.name, arguments,
                    matchedElement.index,
                    expectationTuple.actualCall);
    }

    scope(exit)
    {
        if (matchedElement.repeat_ > 1)
        {
            --matchedElement.repeat_;
        }
        else if (matchedElement.repeat_ == 1)
        {
            overloads.calls = overloads.calls.remove(matchAtIndex.get.index);
        }
    }

    static if (is(Overload.Return == void))
    {
        if (matchedElement.action_ !is null)
        {
            matchedElement.action_(arguments);
        }
    }
    else static if (is(T == interface))
    {
        Overload.Return ret = matchedElement.action_ is null
            ? matchedElement.return_
            : matchedElement.action_(arguments);
    }
    else
    {
        Overload.Return ret = matchedElement.passThrough_
            ? __traits(getMember, super, expectation.name)(arguments)
            : matchedElement.action_ is null
            ? matchedElement.return_
            : matchedElement.action_(arguments);
    }

    static if (!is(T == interface) && is(Overload.Return == void))
    {
        if (matchedElement.passThrough_)
        {
            __traits(getMember, super, expectation.name)(arguments);
        }
    }

    static if (![Overload.qualifiers].canFind("nothrow"))
    {
        if (matchedElement.exception !is null)
        {
            throw matchedElement.exception;
        }
    }
    static if (!is(Overload.Return == void))
    {
        return ret;
    }
};

private auto getExpectationTuple(T)(ref T expectationSetup) @trusted
{
    alias R = typeof(cast() typeof(expectationSetup.expectationTuple).init)*;

    return cast(R) &expectationSetup.expectationTuple;
}

private enum string stubCode = q{
    auto overloads = getExpectationTuple(expectationSetup)
        .methods[j].overloads[i];
    auto match = overloads.find!(call => call.compareArguments!Options(arguments));
    // Continue to search for better matches
    for (auto preliminaryMatch = match; !preliminaryMatch.empty; preliminaryMatch.popFront)
    {
        if (!preliminaryMatch.front.arguments.isNull
                && preliminaryMatch.front.compareArguments!Options(arguments))
        {
            match = preliminaryMatch;
            break;
        }
    }
    if (match.empty)
    {
        throw unexpectedCallError!(typeof(super), Overload.ParameterTypes)(expectation.name, arguments);
    }

    static if (is(Overload.Return == void))
    {
        if (match.front.action_ !is null)
        {
            match.front.action_(arguments);
        }
    }
    else static if (is(T == interface))
    {
        Overload.Return ret = match.front.action_ is null
            ? match.front.return_
            : match.front.action_(arguments);
    }
    else
    {
        Overload.Return ret = match.front.passThrough_
            ? __traits(getMember, super, expectation.name)(arguments)
            : match.front.action_ is null
            ? match.front.return_
            : match.front.action_(arguments);
    }

    static if (!is(T == interface) && is(Overload.Return == void))
    {
        if (match.front.passThrough_)
        {
            __traits(getMember, super, expectation.name)(arguments);
        }
    }

    static if (![Overload.qualifiers].canFind("nothrow"))
    {
        if (match.front.exception !is null)
        {
            throw match.front.exception;
        }
    }
    static if (!is(Overload.Return == void))
    {
        return ret;
    }
};

/**
 * Mocker instance with default options.
 *
 * See_Also: $(D_PSYMBOL Factory), $(D_PSYMBOL configure).
 */
alias Mocker = Factory!(Options!());

/**
 * Constructs a mocker with options passed as $(D_PARAM Args).
 *
 * Params:
 *     Args = Mocker options.
 *
 * See_Also: $(D_PSYMBOL Factory), $(D_PSYMBOL Mocker).
 */
auto configure(Args...)()
{
    return Factory!(Options!Args)();
}

/**
 * A class through which one creates mock objects and manages expectations
 * about calls to their methods.
 *
 * Params:
 *     Options = Mocker $(D_PSYMBOL Options).
 *
 * See_Also: $(D_PSYMBOL Mocker), $(D_PSYMBOL CustomMocker).
 */
struct Factory(Options)
{
    private DList!Verifiable repositories;

    /**
     * Mocks the type $(D_PARAM T).
     *
     * Params:
     *     T = The type to mock.
     *     Args = Constructor parameter types.
     *     args = Constructor arguments.
     *
     * Returns: A mock builder.
     */
    auto mock(T, Args...)(Args args)
    {
        mixin NestedMock!(Repository!T.Mock, Options, Args);

        auto mock = new Mock(args);
        auto mocked = new Mocked!T(mock, mock.expectationSetup);

        this.repositories.insertBack(mocked);
        return mocked;
    }

    /**
     * Stubs the type $(D_PARAM T).
     *
     * Params:
     *     T = The type to stub.
     *     Args = Constructor parameter types.
     *     args = Constructor arguments.
     *
     * Returns: A stub builder.
     */
    auto stub(T, Args...)(Args args)
    if (isPolymorphicType!T)
    {
        mixin NestedMock!(Repository!T.Stub, Options, Args);

        auto stub = new Mock(args);

        return new Stubbed!T(stub, stub.expectationSetup);
    }

    /**
     * Verifies that certain expectation requirements were satisfied.
     *
     * Throws: $(D_PSYMBOL ExpectationViolationException) if those issues occur.
     */
    void verify()
    {
        this.repositories.each!(repository => repository.verify);
    }

    ~this()
    {
        verify;
    }
}

/**
 * Mock builder.
 *
 * Params:
 *     T = Mocked type.
 */
final class Mocked(T) : Builder!T, Verifiable
{
    private Repository!T.Mock* repository;

    /**
     * Params:
     *     mock = Mocked object.
     *     repository = Mock repository.
     */
    this(T mock, ref Repository!T.Mock repository)
    in (mock !is null)
    {
        super(mock);
        this.repository = &repository;
    }

    /**
     * Returns: Repository used to set up expectations.
     */
    ref Repository!T.Mock expect()
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
            static foreach (i, expectation; this.repository.expectationTuple.Methods)
            {
                static foreach (j, Overload; expectation.Overloads)
                {
                    this.expect.expectationTuple.methods[i].overloads[j].clear();
                }
            }
        }

        static foreach (i, expectation; this.repository.expectationTuple.Methods)
        {
            static foreach (j, Overload; expectation.Overloads)
            {
                foreach (ref call; this.expect.expectationTuple.methods[i].overloads[j])
                {
                    enforce(call.repeat_ <= 0,
                        expectationViolationException!T(expectation.name, call.arguments));
                }
            }
        }
    }

    /**
     * Accept expected calls in a random order.
     *
     * Returns: $(D_KEYWORD this).
     */
    public typeof(this) unordered()
    {
        this.repository.expectationTuple.ordered = false;
        return this;
    }

    alias get this;
}

/**
 * Stub builder.
 *
 * Params:
 *     T = Mocked type.
 */
final class Stubbed(T) : Builder!T
{
    private Repository!T.Stub* repository;

    /**
     * Params:
     *     mock = Stubbed object.
     *     repository = Stub repository.
     */
    this(T mock, ref Repository!T.Stub repository)
    in (mock !is null)
    {
        super(mock);
        this.repository = &repository;
    }

    /**
     * Returns: Repository used to set up stubbed methods.
     */
    ref Repository!T.Stub stub()
    {
        return *this.repository;
    }

    alias get this;
}

/**
 * $(D_PSYMBOL Call) represents a single call of a mocked method.
 *
 * Params:
 *     F = Function represented by this $(D_PSYMBOL Call).
 */
mixin template Call(alias F)
{
    private alias Function = F;

    /// Return type of the mocked method.
    private alias Return = ReturnType!F;

    // Parameters accepted by the mocked method.
    private alias ParameterTypes = .Parameters!F;

    static if (is(FunctionTypeOf!F PT == __parameters))
    {
        /// Arguments passed to set the expectation up.
        private alias Parameters = PT;
    }
    else
    {
        static assert(false, typeof(T).stringof ~ " is not a function");
    }

    /// Attribute set of the mocked method.
    private alias qualifiers = AliasSeq!(__traits(getFunctionAttributes, F));

    private enum concatenatedQualifiers = [qualifiers].join(" ");

    mixin("alias Action = Return delegate(ParameterTypes) "
            ~ concatenatedQualifiers ~ ";");

    private bool passThrough_ = false;
    private Exception exception;
    private Action action_;

    /// Expected arguments if any.
    private alias Arguments = Maybe!ParameterTypes;

    /// ditto
    private Arguments arguments;

    static if (!is(Return == void))
    {
        private Return return_ = Return.init;

        /**
         * Set the value to return when method matching this expectation is called on a mock object.
         *
         * Params:
         *     value = the value to return
         *
         * Returns: $(D_KEYWORD this).
         */
        public ref typeof(this) returns(Return value) @trusted
        {
            import core.stdc.string : memcpy;

            // discard possible immutable
            memcpy(cast(void*) &this.return_, cast(void*) &value, Return.sizeof);

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
     * Compares arguments of this call with the given arguments.
     *
     * Params:
     *     Options = Functions used for comparison.
     *     arguments = Arguments.
     *
     * Returns: Whether the arguments of this call are equal to the given
     *          arguments.
     */
    public bool compareArguments(Options)(ParameterTypes arguments)
    {
        Options options;

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

/// ditto
struct MockCall(alias F)
{
    mixin Call!F;

    private uint repeat_ = 1;
    private size_t index = 0;

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
}

/// ditto
struct StubCall(alias F)
{
    mixin Call!F;
}

/**
 * Function overload representation.
 *
 * Params:
 *     C = Single mocked method call.
 */
private struct Overload(C)
{
    /// Single mocked method call.
    alias Call = C;

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
    @property bool empty()
    {
        return this.calls.empty;
    }

    /**
     * Returns: The next expected call.
     */
    ref Call front()
    in (!this.calls.empty)
    {
        return this.calls.front;
    }

    /**
     * Returns: The last expected call.
     */
    ref Call back()
    in (!this.calls.empty)
    {
        return this.calls.back;
    }

    /**
      * Removes the next expected call from the queue.
      */
    void popFront()
    {
        this.calls.popFront;
    }

    /**
      * Removes the last expected call from the queue.
      */
    void popBack()
    {
        this.calls.popBack;
    }

    /**
     * Clears the queue.
     */
    void clear()
    {
        this.calls = [];
    }

    /**
     * Returns: Number of the queue.
     */
    @property size_t length()
    {
        return this.calls.length;
    }

    /**
     * Returns: $(D_KEYWORD this).
     */
    public Overload save()
    {
        return this;
    }

    /**
     * Params:
     *     i = Index.
     *
     * Returns: The element at index $(D_PARAM i).
     */
    public ref Call opIndex(size_t i)
    in (i < this.calls.length)
    {
        return this.calls[i];
    }
}

/**
 * $(D_PSYMBOL ExpectationSetup) contains all overloads of a single method.
 *
 * Params:
 *     Call = Call interface (mock or stub).
 *     T = Mocked type.
 *     member = Mocked method name.
 */
private struct ExpectationSetup(alias Call, T, string member)
{
    enum string name = member;

    enum bool isVirtualMethod(alias F) = __traits(isVirtualMethod, F);
    alias VirtualMethods = Filter!(isVirtualMethod, __traits(getOverloads, T, member));
    alias Overloads = staticMap!(Overload, staticMap!(Call, VirtualMethods));

    Overloads overloads;
}

/**
 * $(D_PSYMBOL Repository) contains all mocked methods of a single class.
 *
 * Params:
 *     T = Mocked type.
 */
private template Repository(T)
if (isPolymorphicType!T)
{
    enum isVirtualMethod(string member) =
        __traits(isVirtualMethod, __traits(getMember, T, member));
    alias allMembers = __traits(allMembers, T);
    alias VirtualMethods = Filter!(isVirtualMethod, allMembers);

    struct MockSetup
    {
        alias Methods = staticMap!(ApplyLeft!(ExpectationSetup, MockCall, T), VirtualMethods);
        alias Type = T;
        enum string code = mockCode;

        Methods methods;
        private size_t lastCall_;
        public size_t actualCall;
        bool ordered = true;

        public @property size_t lastCall()
        {
            return ++this.lastCall_;
        }
    }

    struct StubSetup
    {
        alias Methods = staticMap!(ApplyLeft!(ExpectationSetup, StubCall, T), VirtualMethods);
        alias Type = T;
        enum string code = stubCode;
        Methods methods;
    }

    struct Mock
    {
        MockSetup expectationTuple;

        static foreach (i, member; VirtualMethods)
        {
            static foreach (j, overload; expectationTuple.Methods[i].Overloads)
            {
                mixin(format!mockProperty(member, i, j));
            }

            static if (!anySatisfy!(hasNoArguments, expectationTuple.Methods[i].Overloads))
            {
                mixin(format!mockProperty0(member, i));
            }
        }
    }

    struct Stub
    {
        StubSetup expectationTuple;

        static foreach (i, member; VirtualMethods)
        {
            static foreach (j, overload; expectationTuple.Methods[i].Overloads)
            {
                mixin(format!stubProperty(member, i, j));
            }

            static if (!anySatisfy!(hasNoArguments, expectationTuple.Methods[i].Overloads))
            {
                mixin(format!stubProperty0(member, i));
            }
        }
    }
}

private enum string mockProperty0 = q{
    ref auto %1$s(Args...)()
    {
        static if (Args.length == 0)
        {
            enum ptrdiff_t index = 0;
        }
        else
        {
            enum ptrdiff_t index = matchArguments!(Pack!Args, expectationTuple.Methods[%2$s].Overloads);
        }
        static assert(index >= 0,
                "%1$s overload with the given argument types could not be found");

        this.expectationTuple.methods[%2$s].overloads[index].calls ~=
            this.expectationTuple.Methods[%2$s].Overloads[index].Call(this.expectationTuple.lastCall);
        return this.expectationTuple.methods[%2$s].overloads[index].back;
    }
};

private enum string mockProperty = q{
    ref auto %1$s(overload.Parameters arguments)
    {
        this.expectationTuple.methods[%2$s].overloads[%3$s].calls ~=
            overload.Call(this.expectationTuple.lastCall);
        this.expectationTuple.methods[%2$s].overloads[%3$s].back.arguments = arguments;
        return this.expectationTuple.methods[%2$s].overloads[%3$s].back;
    }
};

private enum string stubProperty = q{
    ref auto %1$s(overload.Parameters arguments)
    {
        /**
         * Why is this a nested function?
         * Due to the `__parameters` hack used to form `overload.Parameters`,
         * the individual parameter names of the overload - *not* just `arguments`! -
         * are also valid in this scope and may introduce identifier collisions
         * with `call`.
         * Sidestep this by opening a new function.
         */
        return delegate ref(){
            foreach (ref call; this.expectationTuple.methods[%2$s].overloads[%3$s])
            {
                if (!call.arguments.isNull && call.arguments.get == tuple(arguments))
                {
                    return call;
                }
            }
            this.expectationTuple.methods[%2$s].overloads[%3$s].calls ~= overload.Call();
            this.expectationTuple.methods[%2$s].overloads[%3$s].back.arguments = arguments;
            return this.expectationTuple.methods[%2$s].overloads[%3$s].back;
        }();
    }
};

private enum string stubProperty0 = q{
    ref auto %1$s(Args...)()
    {
        static if (Args.length == 0)
        {
            enum ptrdiff_t index = 0;
        }
        else
        {
            enum ptrdiff_t index = matchArguments!(Pack!Args, expectationTuple.Methods[%2$s].Overloads);
        }
        static assert(index >= 0,
                "%1$s overload with the given argument types could not be found");

        if (this.expectationTuple.methods[%2$s].overloads[index].calls.empty)
        {
            this.expectationTuple.methods[%2$s].overloads[index].calls ~=
                this.expectationTuple.Methods[%2$s].Overloads[index].Call();
            return this.expectationTuple.methods[%2$s].overloads[index].back;
        }
        else
        {
            return this.expectationTuple.methods[%2$s].overloads[index].calls.back;
        }
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
abstract class Builder(T)
{
    /// Mocked object instance.
    protected T mock;

    invariant(mock !is null);

    /**
     * Params:
     *     mock = Mocked object.
     */
    this(T mock)
    in (mock !is null)
    {
        this.mock = mock;
    }

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

private mixin template NestedMock(Repository, Options, Args...)
{
    final class Mock : Repository.expectationTuple.Type
    {
        import std.string : join;

        private Repository expectationSetup;

        static if (__traits(hasMember, Repository.expectationTuple.Type, "__ctor")
                && Args.length > 0)
        {
            this(ref Args args)
            {
                super(args);
            }
        }
        else static if (__traits(hasMember, Repository.expectationTuple.Type, "__ctor"))
        {
            this()
            {
                super(Parameters!(Repository.expectationTuple.Type.__ctor).init);
            }
        }

        static foreach (j, expectation; expectationSetup.expectationTuple.Methods)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                mixin(["override", Overload.qualifiers, "Overload.Return", expectation.name].join(" ") ~ q{
                    (Overload.ParameterTypes arguments)
                    {
                        mixin(Repository.expectationTuple.code);
                    }
                });
            }
        }
    }
}
