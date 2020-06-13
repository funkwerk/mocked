module mocked.tests.alien;

import dshould;
import mocked;
import unit_threaded : DontTest, ShouldFail;

version (unittest)
{
    class Templated(T)
    {
    }

    interface IM
    {
        void bar();
    }

    class ConstructorArg
    {
        int a;

        this(int i)
        {
            this.a = i;
        }

        int getA()
        {
            return this.a;
        }
    }

    class SimpleObject
    {
        this()
        {
        }

        void print()
        {
            import std.stdio : writeln;

            writeln(toString());
        }
    }

    interface IRM
    {
        IM get();
        void set(IM im);
    }

    class HasPrivateMethods
    {
        protected void method()
        {
        }
    }

    interface IFace
    {
        void foo(string s);
    }

    class Smthng : IFace
    {
        void foo(string)
        {
        }
    }

    class HasMember
    {
        int member;
    }

    class Overloads
    {
        void foo()
        {
        }

        void foo(int)
        {
        }
    }

    class Qualifiers
    {
        int make() shared
        {
            return 0;
        }

        int make() const
        {
            return 1;
        }

        int make() shared const
        {
            return 2;
        }

        int make()
        {
            return 3;
        }

        int make() immutable
        {
            return 4;
        }
    }

    interface VirtualFinal
    {
        int makeVir();
    }

    class MakeAbstract
    {
        int con;
        this(int con)
        {
            this.con = con;
        }

        abstract int abs();

        int concrete()
        {
            return con;
        }
    }

    class FinalMethods : VirtualFinal
    {
        final int make()
        {
            return 0;
        }

        final int make(int)
        {
            return 2;
        }

        int makeVir()
        {
            return 5;
        }
    }

    final class FinalClass
    {
        int fortyTwo()
        {
            return 42;
        }
    }

    class TemplateMethods
    {
        string get(T)(T)
        {
            import std.traits;

            return fullyQualifiedName!T;
        }

        int getSomethings(T...)(T)
        {
            return T.length;
        }
    }

    struct Struct
    {
        int get()
        {
            return 1;
        }
    }

    struct StructWithFields
    {
        int field;

        int get()
        {
            return field;
        }
    }

    struct StructWithConstructor
    {
        int field;

        this(int i)
        {
            field = i;
        }

        int get()
        {
            return field;
        }
    }

    class Dependency
    {
        private int[] arr = [1, 2];
        private int index = 0;
        public int foo()
        {
            return arr[index++];
        }
    }

    class TakesFloat
    {
        public void foo(float)
        {
        }
    }

    class Property
    {
        private int _foo;

        @property int foo()
        {
            return _foo;
        }

        @property void foo(int i)
        {
            _foo = i;
        }

        @property T foot(T)()
        {
            static if (is(T == int))
            {
                return _foo;
            }
            else
            {
                return T.init;
            }
        }

        @property void foot(T)(T i)
        {
            static if (is(T == int))
            {
                _foo = i;
            }
        }
    }

}

@("nontemplated mock")
unittest
{
    Mocker().mock!(Object)();
}

@("templated mock")
unittest
{
    static assert(is(typeof(Mocker().mock!(Templated!(int))())));
}

@("interface mock")
unittest
{
    static assert(is(typeof(Mocker().mock!IM())));
}

@("constructor argument")
unittest
{
    Mocker mocker;

    static assert(is(typeof(mocker.mock!(ConstructorArg)(4))));
}

@DontTest
class TestClass
{
    string test()
    {
        return "test";
    }

    string test1()
    {
        return "test 1";
    }

    string test2()
    {
        return "test 2";
    }

    int test_int(int i)
    {
        return i;
    }
}

@("unexpected call")
unittest
{
    Mocker mocker;
    TestClass cl = mocker.mock!(TestClass);

    cl.test.should.throwA!UnexpectedCallError;
    mocker.verify;
}

@ShouldFail("expect")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().repeat(0).returns("mrow?");

    cl.test;
}

@("expect mismatched type")
version (none) unittest
{
    Mocker mocker;
    TestClass cl = mocker.mock!(TestClass);

    void call_test(T)(T arg)
    {
        mocker.expectT!(cl, "test_int")(arg);
    }

    static assert(__traits(compiles, call_test(5)));
    static assert(!__traits(compiles, call_test("string")));

    void return_test(T)(T arg)
    {
        mocker.expectT!(cl, "test_int")(5).returns(arg);
    }

    static assert(__traits(compiles, return_test(5)));
    static assert(!__traits(compiles, return_test("string")));
}

@("repeat single")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().repeat(2).returns("foom?");

    cl.test;
    cl.test;

    cl.test.should.throwAn!UnexpectedCallError;
}

@ShouldFail("repository match counts")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!TestClass;

    cl.expect.test().repeat(2).returns("mew.");

    mocker.verify();
}

@("delegate payload")
unittest
{
    bool calledPayload = false;
    Mocker mocker;
    auto obj = mocker.mock!SimpleObject;

    obj.expect.print().action({ calledPayload = true; });

    obj.print;

    calledPayload.should.be(true);
}

@("delegate payload with mismatching parameters")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!SimpleObject;

    static assert(!is(typeof(obj.expect.print().action((int) {}))));
}

@("exception payload")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(SimpleObject);

    enum string msg = "divide by cucumber error";
    obj.expect.print().throws(new Exception(msg));

    obj.print.should.throwAn!Exception.where.msg.should.equal(msg);
}

@("passthrough")
unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.expect.test().passThrough;

    string str = cl.test;
    str.should.equal("test");
}

@("class with constructor init check")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!ConstructorArg(4);

    obj.expect.getA().passThrough;

    obj.getA().should.equal(4);
}

@("associative arrays")
unittest
{
    Mocker mocker;

    auto mock = mocker.mock!(Object);
    mock.expect.toHash().passThrough().repeatAny;
    mock.expect.opEquals(null).ignoreArgs().passThrough().repeatAny;

    auto obj = mock.getMock;

    int[Object] i;
    i[obj] = 5;
    int j = i[obj];
}

@("ordering in order")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(Object);
    mocker.ordered;
    mocker.expect(obj.toHash).returns(cast(hash_t) 5);
    mocker.expect(obj.toString).returns("mow!");

    mocker.replay();
    obj.toHash;
    obj.toString;
    mocker.verify;
}

@("ordering not in order")
version (none) unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    mocker.ordered;
    mocker.expect(cl.test1).returns("mew!");
    mocker.expect(cl.test2).returns("mow!");

    mocker.replay();

    assertThrown!ExpectationViolationError(cl.test2);
}

@("ordering interposed")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(SimpleObject);
    mocker.ordered;
    mocker.expect(obj.toHash).returns(cast(hash_t) 5);
    mocker.expect(obj.toString).returns("mow!");
    mocker.unordered;
    obj.print;

    mocker.replay();
    obj.toHash;
    obj.print;
    obj.toString;
}

@("allow unexpected")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(Object);
    mocker.ordered;
    mocker.allowUnexpectedCalls(true);
    mocker.expect(obj.toString).returns("mow!");
    mocker.replay();
    obj.toHash; // unexpected tohash calls
    obj.toString;
    obj.toHash;
    assertThrown!ExpectationViolationError(mocker.verify(false, true));
    mocker.verify(true, false);
}

@("allowing")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(Object);
    mocker.allowing(obj.toString).returns("foom?");

    mocker.replay();
    obj.toString;
    obj.toString;
    obj.toString;
    mocker.verify;
}

@("nothing for method to do")
version (none) unittest
{
    try
    {
        Mocker mocker;
        auto cl = mocker.mock!(TestClass);
        mocker.allowing(cl.test);

        mocker.replay();
        assert(false, "expected a mocks setup exception");
    }
    catch (MocksSetupException e)
    {
    }
}

@("allow defaults test")
version (none) unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    mocker.allowDefaults;
    mocker.allowing(cl.test);

    mocker.replay();
    assert(cl.test == (char[]).init);
}

@("mock interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!IFace;

    obj.expect.foo("hallo");

    obj.getMock.foo("hallo");

    mocker.verify;
}

@("cast mock to interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!Smthng;

    obj.expect.foo("hallo");

    obj.getMock.foo("hallo");

    mocker.verify;
}

@("cast mock to interface")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!Smthng;

    obj.expect.foo("hallo");

    obj.foo("hallo");

    mocker.verify;
}

@("return user-defined type")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(IRM);
    auto imBuilder = mocker.mock!(IM);
    auto im = imBuilder.getMock;

    obj.expect.get().returns(im);
    obj.expect.set(im);

    obj.get.should.be(im);
    obj.set(im);
    mocker.verify;
}

@("return user-defined type")
unittest
{
    Mocker mocker;
    mocker.mock!HasMember;
}

@("overloaded method")
unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(Overloads);
    obj.expect.foo();
    obj.expect.foo(1);

    obj.foo(1);
    obj.foo;

    mocker.verify;
}

@("overloaded method qualifiers")
version (none) unittest
{
    {
        auto mocker = new Mocker;
        auto s = mocker.mock!(shared(Qualifiers));
        auto sc = cast(shared const) s;

        mocker.expect(s.make).passThrough;
        mocker.expect(sc.make).passThrough;
        mocker.replay;

        assert(s.make == 0);
        assert(sc.make == 2);

        mocker.verify;
    }
    {
        auto mocker = new Mocker;
        auto m = mocker.mock!(Qualifiers);
        auto c = cast(const) m;
        auto i = cast(immutable) m;

        mocker.expect(i.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.expect(c.make).passThrough;
        mocker.replay;

        assert(i.make == 4);
        assert(m.make == 3);
        assert(c.make == 1);

        mocker.verify;
    }
    {
        auto mocker = new Mocker;
        auto m = mocker.mock!(Qualifiers);
        auto c = cast(const) m;
        auto i = cast(immutable) m;

        mocker.expect(i.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.expect(m.make).passThrough;
        mocker.replay;

        assert(i.make == 4);
        assert(m.make == 3);
        assertThrown!ExpectationViolationError(c.make);
    }
}

@("final mock of virtual methods")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(VirtualFinal);
    mocker.expect(obj.makeVir()).returns(5);
    mocker.replay;
    assert(obj.makeVir == 5);
}

@("final mock of abstract methods")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(MakeAbstract)(6);
    mocker.expect(obj.concrete()).passThrough;
    mocker.replay;
    assert(obj.concrete == 6);
    mocker.verify;
}

@("final methods")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(FinalMethods);
    mocker.expect(obj.make()).passThrough;
    mocker.expect(obj.make(1)).passThrough;
    mocker.replay;
    static assert(!is(typeof(o) == FinalMethods));
    assert(obj.make == 0);
    assert(obj.make(1) == 2);
    mocker.verify;
}

@("final class")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(FinalClass);
    mocker.expect(obj.fortyTwo()).passThrough;
    mocker.replay;
    assert(obj.fortyTwo == 42);
    mocker.verify;
}

@("final class with no underlying object")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinalPassTo!(FinalClass)(null);
    mocker.expect(obj.fortyTwo()).returns(43);
    mocker.replay;
    assert(obj.fortyTwo == 43);
    mocker.verify;
}

@("template methods")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockFinal!(TemplateMethods);
    mocker.expect(obj.get(1)).passThrough;
    mocker.expect(obj.getSomethings(1, 2, 3)).passThrough;
    mocker.replay;
    assert(obj.get(1) == "int");
    auto tm = new TemplateMethods();
    assert(obj.getSomethings(1, 2, 3) == 3);
    mocker.verify;
}

@("returning different values on the same expectation")
unittest
{
    Mocker mocker;
    auto dependency = mocker.mock!Dependency;

    //mocker.ordered;
    dependency.expect.foo.returns(1);
    dependency.expect.foo.returns(2);

    dependency.foo.should.equal(1);
    dependency.foo.should.equal(2);

    mocker.verify;
}

@("customArgsComparator")
unittest
{
    import std.math;

    enum float argument = 1.0f;

    auto mocker = configure!(Comparator!((float a, float b) => abs(a - b) < 0.1f));
    auto dependency = mocker.mock!TakesFloat;
    dependency.expect.foo(argument).repeat(2);

    // custom comparison example - treat similar floats as equals
    dependency.foo(1.01);
    dependency.foo(1.02);
}
