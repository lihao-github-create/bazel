#include "libs/math/math.h"

#include <gtest/gtest.h>

TEST(AddTest, PositiveNumbers) {
    EXPECT_EQ(add(2, 3), 5);
}

TEST(AddTest, NegativeNumbers) {
    EXPECT_EQ(add(-2, -3), -5);
}

TEST(AddTest, MixedSigns) {
    EXPECT_EQ(add(-2, 3), 1);
}

TEST(AddTest, Zero) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(5, 0), 5);
    EXPECT_EQ(add(0, 5), 5);
}