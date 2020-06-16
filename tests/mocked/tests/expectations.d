module mocked.tests.expectations;

import dshould;
import dshould.ShouldType;
import mocked;
import std.algorithm;
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
        .where.toString
        .should.startWith(`Unexpected call: Dependency.say("Ton der Jugend", "zu laut.")`);
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
        .where.toString.should.contain.any("\n");
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
        .where.toString.should.startWith(
                `Expected method not called: Dependency.say("` ~ phrase ~ `")`
        );
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
