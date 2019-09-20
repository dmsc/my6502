/* CC0 (Public domain) - see LICENSE file for details */
#pragma once

#include <stdbool.h>

/**
 * likely - indicate that a condition is likely to be true.
 * @cond: the condition
 *
 * This uses a compiler extension where available to indicate a likely
 * code path and optimize appropriately; it's also useful for readers
 * to quickly identify exceptional paths through functions.  The
 * threshold for "likely" is usually considered to be between 90 and
 * 99%; marginal cases should not be marked either way.
 *
 * See Also:
 *	unlikely(), likely_stats()
 *
 * Example:
 *	// Returns false if we overflow.
 *	static inline bool inc_int(unsigned int *val)
 *	{
 *		(*val)++;
 *		if (likely(*val))
 *			return true;
 *		return false;
 *	}
 */
#define likely(cond) __builtin_expect(!!(cond), 1)

/**
 * unlikely - indicate that a condition is unlikely to be true.
 * @cond: the condition
 *
 * This uses a compiler extension where available to indicate an unlikely
 * code path and optimize appropriately; see likely() above.
 *
 * See Also:
 *	likely(), likely_stats(), COLD (compiler.h)
 *
 * Example:
 *	// Prints a warning if we overflow.
 *	static inline void inc_int(unsigned int *val)
 *	{
 *		(*val)++;
 *		if (unlikely(*val == 0))
 *			fprintf(stderr, "Overflow!");
 *	}
 */
#define unlikely(cond) __builtin_expect(!!(cond), 0)

