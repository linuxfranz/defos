#define DLIB_LOG_DOMAIN "defos"
#include <dmsdk/sdk.h>

#if defined(DM_PLATFORM_OSX)

#include "defos_private.h"
#include <AppKit/AppKit.h>
#include <CoreGraphics/CoreGraphics.h>

static NSWindow* window = nil;
static NSCursor* current_cursor = nil;
static NSCursor* default_cursor = nil;

static bool is_maximized = false;
static bool is_mouse_in_view = false;
static bool is_cursor_visible = true;
static bool is_cursor_locked = false;
static bool is_cursor_clipped = false;
static NSRect previous_state;

static void enable_mouse_tracking();
static void disable_mouse_tracking();

void defos_init() {
    window = dmGraphics::GetNativeOSXNSWindow();
    // [window disableCursorRects];
    // [window resetCursorRects];
    default_cursor = NSCursor.arrowCursor;
    current_cursor = default_cursor;
    [current_cursor retain];
    enable_mouse_tracking();
}

void defos_final() {
    disable_mouse_tracking();
    [current_cursor release];
    current_cursor = nil;
}

void defos_update() {
}

void defos_event_handler_was_set(DefosEvent event) {
}

void defos_disable_maximize_button() {
    [[window standardWindowButton:NSWindowZoomButton] setHidden:YES];
}

void defos_disable_minimize_button() {
    [[window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
}

void defos_disable_window_resize() {
    [window setStyleMask:[window styleMask] & ~NSResizableWindowMask];
}

void defos_toggle_fullscreen() {
    if (is_maximized){
        defos_toggle_maximized();
    }
    [window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [window toggleFullScreen:window];
}

void defos_toggle_maximized() {
    if (defos_is_fullscreen()){
        defos_toggle_fullscreen();
    }
    if (is_maximized){
        is_maximized = false;
        [window setFrame:previous_state display:YES];
    }
    else
    {
        is_maximized = true;
        previous_state = [window frame];
        [window setFrame:[[NSScreen mainScreen] visibleFrame] display:YES];
    }
}

bool defos_is_fullscreen() {
    BOOL fullscreen = (([window styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask);
    return fullscreen == YES;
}

bool defos_is_maximized() {
    return is_maximized;
}

void defos_set_window_title(const char* title_lua) {
    NSString* title = [NSString stringWithUTF8String:title_lua];
    [window setTitle:title];
}

void defos_set_window_icon(const char *icon_path){
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:icon_path];
        NSImage* image = [[NSImage alloc] initWithContentsOfFile: path];
        [window setRepresentedURL:[NSURL URLWithString:path]];
        [[window standardWindowButton:NSWindowDocumentIconButton] setImage:image];
        [image release];
    }
}

char* defos_get_bundle_root() {
    const char *bundlePath = [[[NSBundle mainBundle] bundlePath] UTF8String];
    char *bundlePath_lua = (char*)malloc(strlen(bundlePath) + 1);
    strcpy(bundlePath_lua, bundlePath);
    return bundlePath_lua;
}

void defos_get_parameters(dmArray<char*>* parameters) {
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    for (int i = 0; i < [args count]; i++){
        const char *param = [args[i] UTF8String];
        char* lua_param = (char*)malloc(strlen(param) + 1);
        strcpy(lua_param, param);
        parameters->OffsetCapacity(1);
        parameters->Push(lua_param);
    }
}

void defos_set_window_size(float x, float y, float w, float h) {
    if (isnan(x)) {
        NSRect frame = window.screen.frame;
        x = floorf(frame.origin.x + (frame.size.width - w) * 0.5f);
    }
    float win_y;
    if (isnan(y)) {
        NSRect frame = window.screen.frame;
        win_y = floorf(frame.origin.y + (frame.size.height - h) * 0.5f);
    } else {
        // correction for result like on Windows PC
        win_y = NSMaxY(NSScreen.screens[0].frame) - h - y;
    }

    [window setFrame:NSMakeRect(x, win_y, w , h) display:YES];
}

void defos_set_view_size(float x, float y, float w, float h) {
    if (isnan(x)) {
        NSRect frame = window.screen.frame;
        x = floorf(frame.origin.x + (frame.size.width - w) * 0.5f);
    }
    float win_y;
    if (isnan(y)) {
        NSRect frame = window.screen.frame;
        win_y = floorf(frame.origin.y + (frame.size.height - h) * 0.5f);
    } else {
        win_y = NSMaxY(NSScreen.screens[0].frame) - h - y;
    }

    NSView* view = dmGraphics::GetNativeOSXNSView();
    NSRect viewFrame = [view convertRect: view.bounds toView: nil];
    NSRect windowFrame = window.frame;
    NSRect rect = NSMakeRect(
        x - viewFrame.origin.x,
        win_y - viewFrame.origin.x,
        w + viewFrame.origin.x + windowFrame.size.width - viewFrame.size.width,
        h + viewFrame.origin.y + windowFrame.size.height - viewFrame.size.height
    );
    [window setFrame: rect display:YES];
}

WinRect defos_get_window_size() {
    WinRect rect;
    NSRect frame = [window frame];
    rect.x = frame.origin.x;
    rect.y = NSMaxY(NSScreen.screens[0].frame) - NSMaxY(frame);
    rect.w = frame.size.width;
    rect.h = frame.size.height;
    return rect;
}

WinRect defos_get_view_size() {
    WinRect rect;
    NSView* view = dmGraphics::GetNativeOSXNSView();
    NSRect viewFrame = [view convertRect: view.bounds toView: nil];
    NSRect windowFrame = [window frame];
    viewFrame.origin.x += windowFrame.origin.x;
    viewFrame.origin.y += windowFrame.origin.y;
    rect.x = viewFrame.origin.x;
    rect.y = NSMaxY(NSScreen.screens[0].frame) - NSMaxY(viewFrame);
    rect.w = viewFrame.size.width;
    rect.h = viewFrame.size.height;
    return rect;
}

void defos_set_console_visible(bool visible) {
    dmLogInfo("Method 'defos_set_console_visible' is not supported in macOS");
}

bool defos_is_console_visible() {
    return false;
}

void defos_set_cursor_visible(bool visible) {
    if (is_cursor_visible == visible) { return; }
    is_cursor_visible = visible;
    if (visible) {
      [NSCursor unhide];
    } else {
      [NSCursor hide];
    }
}

bool defos_is_cursor_visible() {
  return is_cursor_visible;
}

bool defos_is_mouse_in_view() {
    return is_mouse_in_view;
}

void defos_set_cursor_pos(float x, float y) {
    CGWarpMouseCursorPosition(CGPointMake(x, y));
    if (!is_cursor_locked) {
      CGAssociateMouseAndMouseCursorPosition(true); // Prevents a delay after the Wrap call
    }
}

void defos_move_cursor_to(float x, float y) {
    NSView* view = dmGraphics::GetNativeOSXNSView();
    NSPoint pointInWindow = [view convertPoint: NSMakePoint(x, view.bounds.size.height - y) toView: nil];
    NSPoint windowOrigin = window.frame.origin;
    NSPoint point = NSMakePoint(pointInWindow.x + windowOrigin.x, pointInWindow.y + windowOrigin.y);
    point.y = NSMaxY(NSScreen.screens[0].frame) - point.y;
    defos_set_cursor_pos(point.x, point.y);
}

void defos_set_cursor_clipped(bool clipped) {
    is_cursor_clipped = clipped;
    if (clipped) { is_mouse_in_view = true; }
}

bool defos_is_cursor_clipped() {
    return is_cursor_clipped;
}

static void clip_cursor(NSEvent * event) {
    NSView* view = dmGraphics::GetNativeOSXNSView();
    NSPoint mousePos = [view convertPoint:[event locationInWindow] fromView: nil];
    NSRect bounds = view.bounds;

    bool willClip = false;
    if (mousePos.x < NSMinX(bounds)) {
        willClip = true;
        mousePos.x = NSMinX(bounds);
    }
    if (mousePos.y <= NSMinY(bounds)) {
        willClip = true;
        mousePos.y = NSMinY(bounds) + 1.0;
    }
    if (mousePos.x >= NSMaxX(bounds)) {
        willClip = true;
        mousePos.x = NSMaxX(bounds) - 1.0;
    }
    if (mousePos.y > NSMaxY(bounds)) {
        willClip = true;
        mousePos.y = NSMaxY(bounds);
    }

    if (willClip) {
        defos_move_cursor_to(mousePos.x, bounds.size.height - mousePos.y);
    }
}

extern void defos_set_cursor_locked(bool locked) {
    is_cursor_locked = locked;
    CGAssociateMouseAndMouseCursorPosition(!locked);
}

bool defos_is_cursor_locked() {
    return is_cursor_locked;
}

void defos_set_custom_cursor_mac(dmBuffer::HBuffer buffer, float hotSpotX, float hotSpotY) {
    uint8_t* bytes = NULL;
    uint32_t size = 0;
    if (dmBuffer::GetBytes(buffer, (void**)&bytes, &size) != dmBuffer::RESULT_OK) {
        dmLogError("defos_set_custom_cursor_mac: dmBuffer::GetBytes failed");
        return;
    }

    uint8_t* copy = (uint8_t*)malloc(size);
    memcpy(copy, bytes, size);
    NSData * data = [[NSData alloc] initWithBytesNoCopy:copy length:size freeWhenDone:YES];

    NSImage * image = [[NSImage alloc] initWithData:data];
    NSCursor * cursor = [[NSCursor alloc] initWithImage:image hotSpot:NSMakePoint(hotSpotX, hotSpotY)];
    [current_cursor release];
    current_cursor = cursor;
    [image release];
    [data release];
    [current_cursor set];
}

static NSCursor * get_cursor(DefosCursor cursor) {
    switch (cursor) {
        case DEFOS_CURSOR_ARROW:
            return NSCursor.arrowCursor;
        case DEFOS_CURSOR_HAND:
            return NSCursor.pointingHandCursor;
        case DEFOS_CURSOR_CROSSHAIR:
            return NSCursor.crosshairCursor;
        case DEFOS_CURSOR_IBEAM:
            return NSCursor.IBeamCursor;
        default:
            return NSCursor.arrowCursor;
    }
}

void defos_set_cursor(DefosCursor cur) {
    NSCursor * cursor = get_cursor(cur);
    [cursor set];
    [cursor retain];
    [current_cursor release];
    current_cursor = cursor;
}

void defos_reset_cursor() {
    [default_cursor set];
    [default_cursor retain];
    [current_cursor release];
    current_cursor = default_cursor;
}

@interface DefOSMouseTracker : NSResponder
@end
@implementation DefOSMouseTracker
- (void)mouseEntered:(NSEvent *)event {
    is_mouse_in_view = true;
    if (!is_cursor_clipped) {
        defos_emit_event(DEFOS_EVENT_MOUSE_ENTER);
    }
}
- (void)mouseExited:(NSEvent *)event {
    if (is_cursor_clipped) {
        clip_cursor(event);
    } else {
        is_mouse_in_view = false;
        defos_emit_event(DEFOS_EVENT_MOUSE_LEAVE);
    }
}
// For some reason this doesn't get called and the homonymous method
// gets called on the view instead
- (void)cursorUpdate:(NSEvent *)event {
    [current_cursor set];
}
@end

// This is unstable in case Defold renames this class
// Maybe use the objc runtime to hook this method if there's no better solution?
@interface GLFWContentView
@end
@interface GLFWContentView(CursorUpdate)
- (void)cursorUpdate:(NSEvent *)event;
@end
@implementation GLFWContentView(CursorUpdate)
- (void)cursorUpdate:(NSEvent *)event {
    [current_cursor set];
}
@end

static DefOSMouseTracker* mouse_tracker = nil;
static NSTrackingArea* tracking_area = nil;

static void enable_mouse_tracking() {
    if (tracking_area) { return; }
    NSView * view = dmGraphics::GetNativeOSXNSView();
    mouse_tracker = [[DefOSMouseTracker alloc] init];
    tracking_area = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
        options: NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingCursorUpdate
        owner: mouse_tracker
        userInfo: nil
    ];
    [view addTrackingArea:tracking_area];
    [tracking_area release];
}

static void disable_mouse_tracking() {
    if (!tracking_area) { return; }

    [dmGraphics::GetNativeOSXNSView() removeTrackingArea:tracking_area];
    tracking_area = nil;

    [mouse_tracker release];
    mouse_tracker = nil;
}

#endif
