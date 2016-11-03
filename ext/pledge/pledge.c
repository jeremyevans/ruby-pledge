#include <errno.h>
#include <ruby.h>
#include <unistd.h>

static VALUE ePledgeInvalidPromise;
static VALUE ePledgePermissionIncreaseAttempt;
static VALUE ePledgeError;

static VALUE rb_pledge(VALUE pledge_class, VALUE promises) {
  SafeStringValue(promises);
  promises = rb_str_dup(promises);

  /* required for ruby to work */
  rb_str_cat2(promises, " stdio");
  promises = rb_funcall(promises, rb_intern("strip"), 0);
  SafeStringValue(promises);

  if (pledge(RSTRING_PTR(promises), NULL) != 0) {
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

void Init_pledge(void) {
  VALUE cPledge;
  cPledge = rb_define_module("Pledge");
  rb_define_method(cPledge, "pledge", rb_pledge, 1);
  rb_extend_object(cPledge, cPledge);
  ePledgeError = rb_define_class_under(cPledge, "Error", rb_eStandardError);
  ePledgeInvalidPromise = rb_define_class_under(cPledge, "InvalidPromise", ePledgeError);
  ePledgePermissionIncreaseAttempt = rb_define_class_under(cPledge, "PermissionIncreaseAttempt", ePledgeError);
}
