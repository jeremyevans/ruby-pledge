#include <errno.h>
#include <ruby.h>
#include <unistd.h>

static VALUE ePledgeInvalidPromise;
static VALUE ePledgePermissionIncreaseAttempt;
static VALUE ePledgeError;
static VALUE ePledgeUnveilError;

static VALUE rb_pledge(int argc, VALUE* argv, VALUE pledge_class) {
  VALUE promises = Qnil;
  VALUE execpromises = Qnil;
  const char * prom = NULL;
  const char * execprom = NULL;

  rb_scan_args(argc, argv, "11", &promises, &execpromises);

  if (!NIL_P(promises)) {
    SafeStringValue(promises);
    promises = rb_str_dup(promises);

    /* required for ruby to work */
    rb_str_cat2(promises, " stdio");
    promises = rb_funcall(promises, rb_intern("strip"), 0);
    SafeStringValue(promises);
    prom = RSTRING_PTR(promises);
  }

  if (!NIL_P(execpromises)) {
    SafeStringValue(execpromises);
    execprom = RSTRING_PTR(execpromises);
  }

  if (pledge(prom, execprom) != 0) {
    switch(errno) {
    case EINVAL:
        rb_raise(ePledgeInvalidPromise, "invalid promise in promises string");
    case EPERM:
        rb_raise(ePledgePermissionIncreaseAttempt, "attempt to increase permissions");
    default:
        rb_raise(ePledgeError, "pledge error");
    }
  }

  return Qnil;
}

#ifdef HAVE_UNVEIL
static VALUE check_unveil(const char * path, const char * perm) {
  if (unveil(path, perm) != 0) {
    switch(errno) {
    case EINVAL:
        rb_raise(ePledgeUnveilError, "invalid permissions value");
    case EPERM:
        rb_raise(ePledgeUnveilError, "attempt to increase permissions, path not accessible, or unveil already locked");
    case E2BIG:
        rb_raise(ePledgeUnveilError, "per-process limit for unveiled paths reached");
    case ENOENT:
        rb_raise(ePledgeUnveilError, "directory in the path does not exist");
    default:
        rb_raise(ePledgeUnveilError, "unveil error");
    }
  }

  return Qnil;
}

static VALUE rb_unveil(VALUE pledge_class, VALUE path, VALUE perm) {
  SafeStringValue(path);
  SafeStringValue(perm);
  return check_unveil(RSTRING_PTR(path), RSTRING_PTR(perm));
}

static VALUE rb_finalize_unveil(VALUE pledge_class) {
  return check_unveil(NULL, NULL);
}
#endif

void Init_pledge(void) {
  VALUE cPledge;
  cPledge = rb_define_module("Pledge");
  rb_define_method(cPledge, "pledge", rb_pledge, -1);
  rb_extend_object(cPledge, cPledge);
  ePledgeError = rb_define_class_under(cPledge, "Error", rb_eStandardError);
  ePledgeInvalidPromise = rb_define_class_under(cPledge, "InvalidPromise", ePledgeError);
  ePledgePermissionIncreaseAttempt = rb_define_class_under(cPledge, "PermissionIncreaseAttempt", ePledgeError);

#ifdef HAVE_UNVEIL
  rb_define_private_method(cPledge, "_unveil", rb_unveil, 2);
  rb_define_private_method(cPledge, "_finalize_unveil!", rb_finalize_unveil, 0);
  ePledgeUnveilError = rb_define_class_under(cPledge, "UnveilError", rb_eStandardError);
#endif
}
