module mocked.tests.stub;

import dshould;
import mocked;
import unit_threaded.attrs : ShouldFail;

@("class can be stubbed")
unittest
{
    static class Dependency
    {
        bool isEven(int number)
        {
            return (number & 1) == 0;
        }
    }
    Mocker mocker;
    auto stubbed = mocker.stub!Dependency;

    stubbed.stub.isEven(6).returns(false);
    stubbed.stub.isEven(5).returns(true);

    Dependency dependency = stubbed.get;

    dependency.isEven(5).should.equal(true);
    dependency.isEven(6).should.equal(false);
}

@("stubs classes with an constructor")
unittest
{
    static class Dependency
    {
        string phrase;

        public this(string phrase)
        {
            this.phrase = phrase;
        }

        public string saySomething()
        {
            return this.phrase;
        }
    }
    auto dependency = Mocker().stub!Dependency("Alea iacta est.");

    dependency.stub.saySomething().passThrough;

    dependency.saySomething().should.equal("Alea iacta est.");
}

@("can use custom comparator")
unittest
{
    import std.math : fabs;

    static class Dependency
    {
        public bool call(float)
        {
            return false;
        }
    }

    alias approxComparator = (float a, float b) {
        return fabs(a - b) <= 0.1;
    };
    auto mocker = configure!(Comparator!approxComparator);
    auto builder = mocker.stub!Dependency;

    builder.stub.call(1.01).returns(true);

    auto stub = builder.get;

    stub.call(1.02).should.be(true);
}

@("stubs const methods")
unittest
{
    interface I
    {
        public bool isI(string) const;
    }
    Mocker mocker;

    static assert(is(typeof(mocker.stub!I())));
}

@("overrides returned value")
unittest
{
    enum string leibniz = "Unsere Welt ist die beste aller möglichen Welten";
    enum string schopenhauer =
        "Unsere Welt ist die schlechteste aller möglichen Welten";
    static class X
    {
        string phrase()
        {
            return null;
        }
    }
    Mocker mocker;
    auto builder = mocker.stub!X;

    builder.stub.phrase.returns(leibniz);
    builder.stub.phrase.returns(schopenhauer);

    builder.get.phrase.should.equal(schopenhauer);
}

@("overrides default stub")
unittest
{
    static class Dependency
    {
        string translate(string)
        {
            assert(false);
        }
    }
    Mocker mocker;
    auto builder = mocker.stub!Dependency;

    builder.stub.translate!string.returns("im Sinne");
    builder.stub.translate!string.returns("in mente");

    builder.get.translate("latin").should.equal("in mente");
}

@("checks whether arguments were set when overriding")
unittest
{
    static class Dependency
    {
        string translate(string language)
        {
            return language == "latin" ? "in mente" : null;
        }
    }
    Mocker mocker;
    auto builder = mocker.stub!Dependency;

    builder.stub.translate!string.returns("im Sinne");
    builder.stub.translate("latin").returns("in mente");

    builder.get.translate("latin").should.equal("in mente");
}

@ShouldFail("throws if nothing matches")
unittest
{
    static class Dependency
    {
        string translate()
        {
            return "quinta essentia";
        }
    }
    Mocker mocker;
    auto builder = mocker.stub!Dependency;

    builder.get.translate.should.be(null);
}
