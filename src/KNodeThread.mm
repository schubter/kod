#import "common.h"
#import "kconf.h"
#import "KNodeThread.h"
#import "node_kod.h"

#import <node.h>
#import <node_events.h>

using namespace v8;

static Persistent<Object> gKodNodeModule;
static ev_prepare gPrepareNodeWatcher;

static void _KPrepareNode(EV_P_ ev_prepare *watcher, int revents) {
  HandleScope scope;
  kassert(watcher == &gPrepareNodeWatcher);
  kassert(revents == EV_PREPARE);
  //fprintf(stderr, "_KPrepareTick\n"); fflush(stderr);
  
  // Create _kod module
  Local<FunctionTemplate> kod_template = FunctionTemplate::New();
  node::EventEmitter::Initialize(kod_template);
  gKodNodeModule =
      Persistent<Object>::New(kod_template->GetFunction()->NewInstance());
  node_kod_init(gKodNodeModule);
  Local<Object> global = v8::Context::GetCurrent()->Global();
  global->Set(String::New("_kod"), gKodNodeModule);
  
  ev_prepare_stop(&gPrepareNodeWatcher);
}


@implementation KNodeThread


- (id)init {
  if (!(self = [super init])) return nil;
  [self setName:@"se.hunch.kod.node"];
  return self;
}


- (void)main {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // args
  int argc = 2;
  char *argv[] = {NULL,NULL};
  argv[0] = (char*)[[kconf_bundle() executablePath] UTF8String];
  argv[1] = (char*)[[kconf_res_url(@"main.js") path] UTF8String];
  
  // NODE_PATH
  NSString *nodelibPath = [kconf_bundle() sharedSupportPath];
  nodelibPath = [nodelibPath stringByAppendingPathComponent:@"nodelib"];
  const char *NODE_PATH_pch = getenv("NODE_PATH");
  NSString *NODE_PATH;
  if (NODE_PATH_pch) {
    NODE_PATH = [NSString stringWithFormat:@"%@:%s",nodelibPath, NODE_PATH_pch];
  } else {
    NODE_PATH = nodelibPath;
  }
  setenv("NODE_PATH", [NODE_PATH UTF8String], 1);
  
  // register our initializer
  ev_prepare_init(&gPrepareNodeWatcher, _KPrepareNode);
  // set max priority so _KPrepareNode gets called before main.js is executed
  ev_set_priority(&gPrepareNodeWatcher, EV_MAXPRI);
  ev_prepare_start(EV_DEFAULT_UC_ &gPrepareNodeWatcher);
  ev_unref(EV_DEFAULT_UC);
  
  // start
  DLOG("[node] starting in %@", self);
  int exitStatus = node::Start(argc, argv);
  DLOG("[node] exited with status %d in %@", exitStatus, self);
  
  [pool drain];
}


+ (void)handleUncaughtException:(id)err {
  // called in the node thead
  WLOG("[node] unhandled exception: %@", err);
}


@end
