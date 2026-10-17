cc_library(
    name = "math",
    srcs = glob(
        ["*.cpp"],
        exclude = ["*_test.cpp"],
    ),
    hdrs = glob(["*.h"]),
    visibility = [
        "//app:__pkg__",
    ],
)

cc_test(
    name = "math_test",
    size = "small",
    srcs = ["math_test.cpp"],
    deps = [
        ":math",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)