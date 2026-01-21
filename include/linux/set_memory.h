/*
 * Copyright 2017, Michael Ellerman, IBM Corporation.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version
 * 2 as published by the Free Software Foundation;
 */
#ifndef _LINUX_SET_MEMORY_H_
#define _LINUX_SET_MEMORY_H_

/* For ARM64 4.9 kernels, the functions are in asm/cacheflush.h */
#include <asm/cacheflush.h>

#ifndef set_mce_nospec
static inline int set_mce_nospec(unsigned long pfn)
{
	return 0;
}
#endif

#ifndef clear_mce_nospec
static inline int clear_mce_nospec(unsigned long pfn)
{
	return 0;
}
#endif

static inline int set_memory_encrypted(unsigned long addr, int numpages)
{
	return 0;
}

static inline int set_memory_decrypted(unsigned long addr, int numpages)
{
	return 0;
}

#endif /* _LINUX_SET_MEMORY_H_ */
