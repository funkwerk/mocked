module mocked.mocker;

import mocked.builder;
import mocked.rt;
import std.conv;
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
                mixin("override " ~ fullyQualifiedName!(Overload.Return)
                        ~ " " ~ expectation.name
                        ~ "("
                        ~ parameters!Overload
                        ~ ") { if (builder." ~ expectation.name ~ ".overloads["
                        ~ i.to!string ~ "].empty) {return super."
                        ~ expectation.name ~ "(" ~ arguments!Overload ~ "); } "
                        ~ argumentValidation!(expectation.name, i, expectation.Overloads)
                        ~ "auto ret = builder." ~ expectation.name ~ ".overloads["
                        ~ i.to!string ~ "].front.return_;"
                        ~ "builder." ~ expectation.name ~ ".overloads["
                        ~ i.to!string ~ "].popFront;"
                        ~ "return ret; }");
            }
        }
    }

    auto mock = new Mocked();
    auto mocker = MockRepository!T(mock, builder);

    return mocker;
}
