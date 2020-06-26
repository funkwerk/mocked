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

    builder.expect
        .authorOf("[T]he meaning of a word is its use in the language.")
        .returns(expected);

    auto dependency = builder.get;

    assert(dependency.authorOf(phrase) == expected);
}

unittest
{
    import std.math : fabs;

    static class Dependency
    {
        public void call(float)
        {
        }
    }

    // This function is used to compare two floating point numbers that don't
    // match exactly.
    alias approxComparator = (float a, float b) {
        return fabs(a - b) <= 0.1;
    };
    auto mocker = configure!(Comparator!approxComparator);
    auto builder = mocker.mock!Dependency;

    builder.expect.call(1.01);

    auto mock = builder.get;

    mock.call(1.02);

    mocker.verify;
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
    mock.expect.toString.throws(new Exception(""));

    assertThrown!Exception(mock.get.toString);
}
