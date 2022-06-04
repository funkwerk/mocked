module mocked.tests.readme;

import mocked;

unittest
{
    static class Dependency
    {
        string authorOf(string phrase)
        {
            return null;
        }
    }

    enum string phrase = "[T]he meaning of a word is its use in the language.";
    enum string expected = "L. Wittgenstein";

    Mocker mocker;
    auto builder = mocker.mock!Dependency;

    builder.expect.authorOf(phrase).returns(expected);

    auto dependency = builder.get;

    assert(dependency.authorOf(phrase) == expected);
}

unittest
{
    import std.math : abs;

    static class Dependency
    {
        public void call(float)
        {
        }
    }

    // This function is used to compare two floating point numbers that don't
    // match exactly.
    alias approxComparator = (float a, float b) {
        return abs(a - b) <= 0.1;
    };
    Configure!approxComparator mocker;
    auto builder = mocker.mock!Dependency;

    builder.expect.call(1.01);

    auto mock = builder.get;

    mock.call(1.02);
}

unittest
{
    static class Dependency
    {
        bool isTrue()
        {
            return true;
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;
    mock.expect.isTrue.passThrough;

    assert(mock.get.isTrue);
}

unittest
{
    Mocker mocker;
    auto mock = mocker.mock!Object;
    mock.expect.toString.returns("in abstracto");

    assert(mock.get.toString == "in abstracto");
}

unittest
{
    import std.exception : assertThrown;

    Mocker mocker;
    auto mock = mocker.mock!Object;
    mock.expect.toString.throws!Exception("");

    assertThrown!Exception(mock.get.toString);
}

unittest
{
    static bool flag = false;

    static class Dependency
    {
        void setFlag(bool flag)
        {
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;
    mock.expect.setFlag.action((value) { flag = value; });

    mock.get.setFlag(true);

    assert(flag);
}

unittest
{
    enum string expected = "Three times you must say it, then.";
    Mocker mocker;

    auto builder = mocker.mock!Object;
    builder.expect.toString.returns(expected).repeat(3);
    // Or: builder.expect.toString.returns(expected).repeatAny;

    auto mock = builder.get;

    assert(mock.toString() == expected);
    assert(mock.toString() == expected);
    assert(mock.toString() == expected);
}

unittest
{
    static class Dependency
    {
        void say(string)
        {
        }
    }
    Mocker mocker;
    auto mock = mocker.mock!Dependency;
    mock.expect.say("Naturam expelles furca, tamen usque recurret. (Horace)");
    // or mock.expect.say(); to ignore the arguments

    mock.get.say("Naturam expelles furca, tamen usque recurret. (Horace)");
}

unittest
{
    enum string vergil = "tu ne cede malis, sed contra audentior ito.";
    enum string plotinus = "neque est alter hijus universi locus, quam anima";
    static class Dependency
    {
        string authorOf(string)
        {
            return null;
        }
    }
    Mocker mocker;
    auto stub = mocker.stub!Dependency;
    stub.stub.authorOf(vergil).returns("Vergil");
    stub.stub.authorOf(plotinus).returns("Plotinus");

    assert(stub.get.authorOf(vergil) == "Vergil");
    assert(stub.get.authorOf(plotinus) == "Plotinus");
}

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
    auto mock = mocker.mock!Dependency.unordered;

    mock.expect.callFirst;
    mock.expect.callSecond;

    mock.get.callSecond;
    mock.get.callFirst;
}
