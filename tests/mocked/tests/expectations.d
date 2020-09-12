module mocked.tests.expectations;

import dshould;
import dshould.ShouldType;
import mocked;
import unit_threaded : ShouldFail;

void startWith(Should, T)(Should should, T expected,
        Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    auto got = should.got;
    should.check(got.startsWith(expected), expected, got, file, line);
}

@ShouldFail("if an expected method hasn't been called")
unittest
{
    static class Dependency
    {
        string say(string phrase)
        {
            return phrase;
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;

        dependency.expect.say("Man geht zu Grunde,")
            .returns("wenn man immer zu den Gründen geht.");
    }
}

@("repeats expectations infinitely")
unittest
{
    enum expected = "Piscis primum a capite foetat";

    Mocker mocker;

    auto mock = mocker.mock!Object;

    mock.expect.toString().returns(expected).repeatAny;

    Object object = mock.get;

    object.toString.should.equal(expected);
    object.toString.should.equal(expected);

    mocker.verify;
}

@("prints arguments in the unexpected call error message")
unittest
{
    static class Dependency
    {
        void say(string phrase1, string phrase2)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency.get;

    mock.say("Ton der Jugend", "zu laut.")
        .should.throwAn!UnexpectedCallError
        .where.msg.should.be(`Unexpected call: Dependency.say("Ton der Jugend", "zu laut.")`);
}

@("throws once")
unittest
{
    static class Dependency
    {
        void say(string phrase)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say("Die Ängstlichkeit vergiftet die Seele.").repeat(2);

    mocker.verify.should.throwAn!ExpectationViolationException;
    mocker.verify.should.not.throwAn!ExpectationViolationException;
}

@("gives multiline error messages on mismatched arguments")
unittest
{
    static class Dependency
    {
        void say(string phrase)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say("Let's eat, grandma!").repeat(2);

    mock.say("Let's eat grandma!")
        .should.throwAn!UnexpectedArgumentError
        .where.msg.should.be("Expectation failure:
  Expected: Dependency.say(\"Let's eat, grandma!\")
  but got:  Dependency.say(\"Let's eat grandma!\")");
}

@("verify prints what method was expected")
unittest
{
    enum string phrase = "Täglich erstaune ich: ich kenne mich selber nicht!";
    static class Dependency
    {
        void say(string)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say(phrase);

    mocker.verify
        .should.throwAn!ExpectationViolationException
        .where.msg.should.be(`Expected method not called: Dependency.say("` ~ phrase ~ `")`);
}

@("verify prints what method was expected for ints")
unittest
{
    static class Dependency
    {
        void say(int)
        {
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.say(5);

    mocker.verify
        .should.throwAn!ExpectationViolationException
        .where.msg.should.be(`Expected method not called: Dependency.say(5)`);
}

@("allows to pick the overload without specifying the arguments")
unittest
{
    enum string expected = "ad nullius rei essentiam pertinet existentia";
    static class Dependency
    {
        string show(bool x)
        {
            return x ? "true" : "false";
        }

        string show(string x)
        {
            return x;
        }
    }
    Mocker mocker;

    auto mock = mocker.mock!Dependency;

    mock.expect.show!string.returns(expected);

    auto dependency = mock.get;

    dependency.show(null).should.equal(expected);
}

@("allows to pick the overload without specifying the arguments")
unittest
{
    static class Dependency
    {
        void show(string, string)
        {
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;

    static assert(!is(typeof(mock.expect.show!string)));
}

@("skips private overloads")
unittest
{
    static class Dependency
    {
        void handle(string)
        {
        }

        private void handle(int)
        {
        }
    }
    Mocker mocker;
    static assert(is(typeof(mocker.mock!Dependency())));
}

@("picks public overload")
unittest
{
    static class Dependency
    {
        private void handle(int)
        {
        }

        void handle(string)
        {
        }
    }
    Mocker mocker;
    auto builder = mocker.mock!Dependency();

    builder.expect.handle("In vino veritas");

    builder.get.handle("In vino veritas");
}

@("lets .repeatAny() do a forward lookup")
unittest
{
    static class Dependency
    {
        string finishQuote(string phrase)
        {
            return phrase;
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;

    mock.expect
        .finishQuote("Ducunt volentem fata,")
        .returns("nolentem trahunt")
        .repeatAny;
    mock.expect.finishQuote("Seneca").returns("epistulae");

    mock.get.finishQuote("Seneca").should.equal("epistulae");
}

@ShouldFail("if functions are called not in the given order")
unittest
{
    static class Dependency
    {
        void callFirst()
        {
        }

        void callSecond()
        {
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;

    mock.expect.callFirst;
    mock.expect.callSecond;

    mock.get.callSecond;
    mock.get.callFirst;
}

@("supports const method")
unittest
{
    static class Dependency
    {
        void act() const
        {
        }
    }
    Mocker mocker;
    auto builder = mocker.mock!Dependency();

    builder.expect.act;

    builder.act;
}

@("works with Nullables")
unittest
{
    import std.typecons : Nullable, nullable;

    static class Dependency
    {
        void say(Nullable!string phrase)
        {
        }
    }
    with (Mocker())
    {
        auto dependency = mock!Dependency;
        auto expected = nullable("procul, o procul...");

        dependency.expect.say(nullable("procul, o procul..."));

        dependency.say(Nullable!string())
            .should.throwAn!UnexpectedArgumentError;
    }
}

@("allows functions to be called not in the given order")
unittest
{
    static class Dependency
    {
        void callFirst(int)
        {
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency.unordered;

    mock.expect.callFirst(1);
    mock.expect.callFirst(2);

    mock.get.callFirst(2);
    mock.get.callFirst(1);
}
