module mocked.tests.alien;

import dshould;
import mocked;
import unit_threaded : DontTest;

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
        this(int i)
        {
            a = i;
        }

        int a;
        int getA()
        {
            return a;
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
        void foo(string s)
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

        void foo(int i)
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

        final int make(int i)
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
        string get(T)(T t)
        {
            import std.traits;

            return fullyQualifiedName!T;
        }

        int getSomethings(T...)(T t)
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
        public void foo(float a)
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
    static assert(is(typeof(Mocker().mock!(Object)())));
}

@("templated mock")
unittest
{
    static assert(is(typeof(Mocker().mock!(Templated!(int))())));
}

@("templated mock")
version (none) unittest
{
    static assert(is(typeof(Mocker().mock!IM())));
}

@("constructor argument")
unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(ConstructorArg)(4);
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

    cl.test.should.throwA!ExpectationViolationError;
    mocker.verify;
}

@("expect")
version (none) unittest
{
    Mocker mocker;
    TestClass cl = mocker.mock!(TestClass);
    mocker.expect(cl.test).repeat(0).returns("mrow?");
    mocker.replay();
    assertThrown!ExpectationViolationError(cl.test);
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
version (none) unittest
{
    Mocker mocker;
    TestClass cl = mocker.mock!(TestClass);
    mocker.expect(cl.test).repeat(2).returns("foom?");

    mocker.replay();

    cl.test;
    cl.test;
    assertThrown!ExpectationViolationError(cl.test);
}

@("repository match counts")
version (none) unittest
{
    auto mocker = new Mocker();
    auto cl = mocker.mock!(TestClass);

    cl.test;
    mocker.lastCall().repeat(2, 2).returns("mew.");
    mocker.replay();
    assertThrown!ExpectationViolationError(mocker.verify());
}

@("delegate payload")
version (none) unittest
{
    bool calledPayload = false;
    auto mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);

    //obj.print;
    mocker.expect(obj.print).action({ calledPayload = true; });
    mocker.replay();

    obj.print;
    assert(calledPayload);
}

@("delegate payload with mismatching parameters")
version (none) unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(SimpleObject);

    //o.print;
    mocker.expect(obj.print).action((int) {});
    mocker.replay();

    assertThrown!Error(obj.print);
}

@("exception payload")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(SimpleObject);

    string msg = "divide by cucumber error";
    obj.print;
    mocker.lastCall().throws(new Exception(msg));
    mocker.replay();

    try
    {
        obj.print;
        assert(false, "expected exception not thrown");
    }
    catch (Exception e)
    {
        // Careful -- assertion errors derive from Exception
        assert(e.msg == msg, e.msg);
    }
}

@("passthrough")
version (none) unittest
{
    Mocker mocker;
    auto cl = mocker.mock!(TestClass);
    cl.test;
    mocker.lastCall().passThrough();

    mocker.replay();
    string str = cl.test;
    assert(str == "test", str);
}

@("class with constructor init check")
version (none) unittest
{
    auto mocker = new Mocker();
    auto obj = mocker.mock!(ConstructorArg)(4);
    obj.getA();
    mocker.lastCall().passThrough();
    mocker.replay();
    assert(4 == obj.getA());
}

@("associative arrays")
version (none) unittest
{
    Mocker mocker;
    auto obj = mocker.mock!(Object);
    mocker.expect(obj.toHash()).passThrough().repeatAny;
    mocker.expect(obj.opEquals(null)).ignoreArgs().passThrough().repeatAny;

    mocker.replay();
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
version (none) unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(IFace);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("cast mock to interface")
version (none) unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(Smthng);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("cast mock to interface")
version (none) unittest
{
    auto mocker = new Mocker;
    IFace obj = mocker.mock!(Smthng);
    debugLog("about to call once...");
    obj.foo("hallo");
    mocker.replay;
    debugLog("about to call twice...");
    obj.foo("hallo");
    mocker.verify;
}

@("return user-defined type")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(IRM);
    auto im = mocker.mock!(IM);
    debugLog("about to call once...");
    mocker.expect(obj.get).returns(im);
    obj.set(im);
    mocker.replay;
    debugLog("about to call twice...");
    assert(obj.get is im, "returned the wrong value");
    obj.set(im);
    mocker.verify;
}

@("return user-defined type")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(HasMember);
}

@("overloaded method")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mock!(Overloads);
    obj.foo();
    obj.foo(1);
    mocker.replay;
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

@("struct")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(Struct);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 1);
    mocker.verify;
}

@("struct with fields")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(StructWithFields)(5);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 5);
    mocker.verify;
}

@("struct with fields")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStruct!(StructWithConstructor)(5);
    mocker.expect(obj.get).passThrough;
    mocker.replay;
    assert(obj.get() == 5);
    mocker.verify;
}

@("struct with no underlying object")
version (none) unittest
{
    auto mocker = new Mocker;
    auto obj = mocker.mockStructPassTo(StructWithConstructor.init);
    mocker.expect(obj.get).returns(6);
    mocker.replay;
    assert(obj.get() == 6);
    mocker.verify;
}

@("returning different values on the same expectation")
version (none) unittest
{
    auto mocker = new Mocker;
    auto dependency = mocker.mock!Dependency;

    //mocker.ordered;
    mocker.expect(dependency.foo).returns(1);
    mocker.expect(dependency.foo).returns(2);
    mocker.replay;
    assert(dependency.foo == 1);
    assert(dependency.foo == 2);
    mocker.verify;
}

@("customArgsComparator")
version (none) unittest
{
    import std.math;

    auto mocker = new Mocker;
    auto dependency = mocker.mock!TakesFloat;
    mocker.expect(dependency.foo(1.0f)).customArgsComparator(
            (Dynamic a, Dynamic b) {
        if (a.type == typeid(float))
        {
            return (abs(a.get!float() - b.get!float()) < 0.1f);
        }
        return true;
    }).repeat(2);
    mocker.replay;

    // custom comparison example - treat similar floats as equals
    dependency.foo(1.01);
    dependency.foo(1.02);
}