#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "EVAPI.h"

#include "hiredis.h"
#include "async.h"
#include "libev_adapter.h"

typedef struct ev_hiredis_s ev_hiredis_t;

typedef ev_hiredis_t* EV__Hiredis;
typedef struct ev_loop* EV__Loop;

struct ev_hiredis_s {
    struct ev_loop* loop;
    redisAsyncContext* ac;
    SV* error_handler;
    SV* connect_handler;
};

static void emit_error(EV__Hiredis self, SV* error) {
    if (NULL == self->error_handler) return;

    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(error);
    PUTBACK;

    call_sv(self->error_handler, G_DISCARD);

    FREETMPS;
    LEAVE;
}

static void emit_error_str(EV__Hiredis self, char* error) {
    if (NULL == self->error_handler) return;
    emit_error(self, sv_2mortal(newSVpv(error, 0)));
}

static void EV__hiredis_connect_cb(redisAsyncContext* c, int status) {
    EV__Hiredis self = (EV__Hiredis)c->data;

    if (REDIS_OK != status) {
        self->ac = NULL;
        emit_error_str(self, c->errstr);
    }
    else {
        if (NULL == self->connect_handler) return;

        ENTER;
        SAVETMPS;

        call_sv(self->connect_handler, G_DISCARD);

        FREETMPS;
        LEAVE;
    }
}

static void EV__hiredis_disconnect_cb(redisAsyncContext* c, int status) {
    EV__Hiredis self = (EV__Hiredis)c->data;
    SV* sv_error;

    if (REDIS_OK == status) {
        self->ac = NULL;
    }
    else {
        sv_error = sv_2mortal(newSVpv(c->errstr, 0));
        self->ac = NULL;
        emit_error(self, sv_error);
    }
}

static SV* EV__hiredis_decode_reply(redisReply* reply) {
    SV* res;

    switch (reply->type) {
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_ERROR:
        case REDIS_REPLY_STATUS:
            res = sv_2mortal(newSVpvn(reply->str, reply->len));
            break;

        case REDIS_REPLY_INTEGER:
            res = sv_2mortal(newSViv(reply->integer));
            break;
        case REDIS_REPLY_NIL:
            res = sv_2mortal(newSV(0));
            break;

        case REDIS_REPLY_ARRAY: {
            AV* av = (AV*)sv_2mortal((SV*)newAV());
            res = newRV_inc((SV*)av);

            int i;
            for (i = 0; i < reply->elements; i++) {
                av_push(av, EV__hiredis_decode_reply(reply->element[i]));
            }
            break;
        }
    }

    return res;
}

static void EV__hiredis_reply_cb(redisAsyncContext* c, void* reply, void* privdata) {
    SV* cb;
    SV* sv_reply;
    SV* sv_undef;

    cb = (SV*)privdata;
    sv_reply = EV__hiredis_decode_reply((redisReply*)reply);
    sv_undef = sv_2mortal(newSV(0));

    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    if (((redisReply*)reply)->type == REDIS_REPLY_ERROR) {
        PUSHs(sv_undef);
        PUSHs(sv_reply);
    }
    else {
        PUSHs(sv_reply);
    }
    PUTBACK;

    call_sv(cb, G_DISCARD);

    FREETMPS;
    LEAVE;

    SvREFCNT_dec(cb);
}

MODULE = EV::Hiredis PACKAGE = EV::Hiredis

BOOT:
{
    I_EV_API("EV::Hiredis");
}

EV::Hiredis
_new(char* class, EV::Loop loop);
CODE:
{
    PERL_UNUSED_VAR(class);
    Newxz(RETVAL, sizeof(ev_hiredis_t), ev_hiredis_t);
    RETVAL->loop = loop;
}
OUTPUT:
    RETVAL

void
DESTROY(EV::Hiredis self);
CODE:
{
    self->loop = NULL;
    if (NULL != self->ac) {
        redisAsyncFree(self->ac);
        self->ac = NULL;
    }
    if (NULL != self->error_handler) {
        SvREFCNT_dec(self->error_handler);
        self->error_handler = NULL;
    }
    if (NULL != self->connect_handler) {
        SvREFCNT_dec(self->connect_handler);
        self->connect_handler = NULL;
    }
    Safefree(self);
}

void
connect(EV::Hiredis self, char* hostname, int port = 6379);
PREINIT:
    int r;
    SV* sv_error = NULL;
CODE:
{
    if (NULL != self->ac) {
        emit_error_str(self, "already connected");
        return;
    }

    self->ac = redisAsyncConnect(hostname, port);
    if (NULL == self->ac) {
        emit_error_str(self, "cannot allocate memory");
        return;
    }

    self->ac->data = (void*)self;

    if (self->ac->err) {
        sv_error = sv_2mortal(newSVpvf("connect error: %s", self->ac->errstr));
        redisAsyncFree(self->ac);
        self->ac = NULL;
        emit_error(self, sv_error);
        return;
    }

    r = redisLibevAttach(self->loop, self->ac);
    if (REDIS_OK != r) {
        redisAsyncFree(self->ac);
        self->ac = NULL;
        emit_error_str(self, "connect error: cannot attach libev");
        return;
    }

    redisAsyncSetConnectCallback(self->ac, (redisConnectCallback*)EV__hiredis_connect_cb);
    redisAsyncSetDisconnectCallback(self->ac, (redisDisconnectCallback*)EV__hiredis_disconnect_cb);
}

void
connect_unix(EV::Hiredis self, char* path);
PREINIT:
    int r;
    SV* sv_error = NULL;
CODE:
{
    if (NULL != self->ac) {
        emit_error_str(self, "already connected");
        return;
    }

    self->ac = redisAsyncConnectUnix(path);
    if (NULL == self->ac) {
        emit_error_str(self, "cannot allocate memory");
        return;
    }

    self->ac->data = (void*)self;

    if (self->ac->err) {
        sv_error = sv_2mortal(newSVpvf("connect error: %s", self->ac->errstr));
        redisAsyncFree(self->ac);
        self->ac = NULL;
        emit_error(self, sv_error);
        return;
    }

    r = redisLibevAttach(self->loop, self->ac);
    if (REDIS_OK != r) {
        redisAsyncFree(self->ac);
        self->ac = NULL;
        emit_error_str(self, "connect error: cannot attach libev");
        return;
    }

    redisAsyncSetConnectCallback(self->ac, (redisConnectCallback*)EV__hiredis_connect_cb);
    redisAsyncSetDisconnectCallback(self->ac, (redisDisconnectCallback*)EV__hiredis_disconnect_cb);
}

void
disconnect(EV::Hiredis self);
CODE:
{
    if (NULL == self->ac) {
        emit_error_str(self, "not connected");
        return;
    }

    redisAsyncDisconnect(self->ac);
}

CV*
on_error(EV::Hiredis self, CV* handler = NULL);
CODE:
{
    if (NULL != self->error_handler) {
        SvREFCNT_dec(self->error_handler);
        self->error_handler = NULL;
    }

    if (NULL != handler) {
        self->error_handler = SvREFCNT_inc(handler);
    }

    RETVAL = (CV*)self->error_handler;
}
OUTPUT:
    RETVAL

void
on_connect(EV::Hiredis self, CV* handler = NULL);
CODE:
{
    if (NULL != handler) {
        if (NULL != self->connect_handler) {
            SvREFCNT_dec(self->connect_handler);
            self->connect_handler = NULL;
        }

        self->connect_handler = SvREFCNT_inc(handler);
    }

    if (self->connect_handler) {
        ST(0) = self->connect_handler;
        XSRETURN(1);
    }
    else {
        XSRETURN(0);
    }
}

int
command(EV::Hiredis self, ...);
PREINIT:
    SV* cb;
    char** argv;
    size_t* argvlen;
    STRLEN len;
    int argc, i;
CODE:
{
    if (items <= 2) {
        croak("Usage: command(\"command\", ..., $callback)");
    }

    cb = ST(items - 1);
    if (!(SvROK(cb) && SvTYPE(SvRV(cb)) == SVt_PVCV)) {
        croak("last arguments should be CODE reference");
    }

    argc = items - 2;
    Newx(argv, sizeof(char*) * argc, char*);
    Newx(argvlen, sizeof(size_t) * argc, size_t);

    for (i = 0; i < argc; i++) {
        argv[i] = SvPV(ST(i + 1), len);
        argvlen[i] = len;
    }

    RETVAL = redisAsyncCommandArgv(
        self->ac, EV__hiredis_reply_cb, (void*)SvREFCNT_inc(cb),
        argc, (const char**)argv, argvlen
    );

    Safefree(argv);
    Safefree(argvlen);
}
OUTPUT:
    RETVAL

