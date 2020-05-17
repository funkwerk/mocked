import unit_threaded;

import mocked.tests.expectations;
import mocked.tests.mocking;
import mocked.tests.readme;

mixin runTestsMain!(
    mocked.tests.expectations,
    mocked.tests.mocking,
    mocked.tests.readme,
);
