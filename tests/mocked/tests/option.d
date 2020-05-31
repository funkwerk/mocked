module mocked.tests.option;

import dshould;
import mocked;
import mocked.option;

@("sets multiple comparators")
unittest
{
    alias floatComparator = (float, float) => false;
    alias charComparator = (char, char) => true;

    Options!(Comparator!floatComparator, Comparator!charComparator) options;

    options.equal('a', 'a').should.equal(true);
    options.equal(1.2, 1.3).should.equal(false);
}

@("uses custom comparasion")
unittest
{
    alias intComparator = (int a, int b) => false;

    Options!(Comparator!intComparator) options;

    options.equal(5, 5).should.be(false);
}

@("uses fallback comparison")
unittest
{
    alias stringComparator = (string a, string b) => false;

    Options!(Comparator!stringComparator) options;

    options.equal(5, 5).should.be(true);
}
