/*
	Copyright (C) 2014 Quentin Mathe

	Date:  July 2014
	License:  MIT  (see COPYING)
 */

#if TARGET_OS_IPHONE

#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

/* Font and CoreText */

#define NSFont UIFont
#define NSFontSymbolicTraits UIFontDescriptorSymbolicTraits
#define NSFontBoldTrait UIFontDescriptorTraitBold
#define NSFontItalicTrait UIFontDescriptorTraitItalic
#define NSForegroundColorAttributeName (NSString *)kCTForegroundColorAttributeName

/* Color */

#define NSColor UIColor

#endif
