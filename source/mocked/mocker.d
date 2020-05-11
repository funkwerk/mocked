module mocked.mocker;

import mocked.builder;
import mocked.rt;
import std.conv;
import std.format : format;
import std.traits;

// Implementation
auto mock(T)()
{
    Builder!T builder;

    class Mocked : T
    {
        static foreach (expectation; builder.ExpectationTuple)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                mixin(format!q{
                    override Overload.Return %s(Overload.Arguments arguments)
                    {
                        enum member = expectation.name;
                        auto overloads = __traits(getMember, builder, member).overloads[i];

                        if (overloads.empty)
                        {
                            return __traits(getMember, super, member)(arguments);
                        }
                        static foreach (j, argument; arguments)
                        {
                            if (!overloads.front.arguments.isNull
                                && overloads.front.arguments.get!j != argument)
                            {
                                throw new ExpectationViolationError("Expectation failure");
                            }
                        }

                        auto ret = overloads.front.return_;

                        __traits(getMember, builder, member).overloads[i].popFront;
                        return ret;
                    }
                }(expectation.name));
            }
        }
    }

    auto mock = new Mocked();
    auto mocker = MockRepository!T(mock, builder);

    return mocker;
}
