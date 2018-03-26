--[[
   Copyright 2018 American Megatrends Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

local ffi = require("ffi")
-- On SPX base PAM is supported by using libuserauth module. Following are FFI definitions to access the C library functions
ffi.cdef[[

typedef long int time_t;

typedef struct pam_handle pam_handle_t;
struct pam_message {
    int msg_style;
    const char *msg;
};

struct pam_response {
    char *resp;
    int resp_retcode;   /* currently un-used, zero expected */
};

struct pam_conv {
    int (*conv)(int num_msg, const struct pam_message **msg,
        struct pam_response **resp, void *appdata_ptr);
    void *appdata_ptr;
};
struct pam_data {
     char *name;
     void *data;
     void (*cleanup)(pam_handle_t *pamh, void *data, int error_status);
     struct pam_data *next;
};

struct pam_environ {
    int entries;                 /* the number of pointers available */
    int requested;               /* the number of pointers used:     *
                  *     1 <= requested <= entries    */
    char **list;                 /* the environment storage (a list  *
                  * of pointers to malloc() memory)  */
};
typedef enum { PAM_FALSE, PAM_TRUE } _pam_boolean;

struct _pam_fail_delay {
    _pam_boolean set;
    unsigned int delay;
    time_t begin;
    const void *delay_fn_ptr;
};

struct pam_xauth_data {
    int namelen;
    char *name;
    int datalen;
    char *data;
};

struct loaded_module {
    char *name;
    int type; /* PAM_STATIC_MOD or PAM_DYNAMIC_MOD */
    void *dl_handle;
};

struct handler {
    int handler_type;
    int (*func)(pam_handle_t *pamh, int flags, int argc, char **argv);
    int actions[32];
    /* set by authenticate, open_session, chauthtok(1st)
       consumed by setcred, close_session, chauthtok(2nd) */
    int cached_retval; int *cached_retval_p;
    int argc;
    char **argv;
    struct handler *next;
    char *mod_name;
    int stack_level;
    int grantor;
};

struct handlers {
    struct handler *authenticate;
    struct handler *setcred;
    struct handler *acct_mgmt;
    struct handler *open_session;
    struct handler *close_session;
    struct handler *chauthtok;
};


struct service {
    struct loaded_module *module; /* Array of modules */
    int modules_allocated;
    int modules_used;
    int handlers_loaded;

    struct handlers conf;        /* the configured handlers */
    struct handlers other;       /* the default handlers */
};

/* initial state in substack */
struct _pam_substack_state {
    int impression;
    int status;
};

struct _pam_former_state {
/* this is known and set by _pam_dispatch() */
    int choice;            /* which flavor of module function did we call? */

/* state info for the _pam_dispatch_aux() function */
    int depth;             /* how deep in the stack were we? */
    int impression;        /* the impression at that time */
    int status;            /* the status before returning incomplete */
    struct _pam_substack_state *substates; /* array of initial substack states */

/* state info used by pam_get_user() function */
    int fail_user;
    int want_user;
    char *prompt;          /* saved prompt information */

/* state info for the pam_chauthtok() function */
    _pam_boolean update;
};

struct pam_handle {
    char *authtok;
    unsigned caller_is;
    struct pam_conv *pam_conversation;
    char *oldauthtok;
    char *prompt;                /* for use by pam_get_user() */
    char *service_name;
    char *user;
    char *rhost;
    char *ruser;
    char *tty;
    char *xdisplay;
    char *authtok_type;          /* PAM_AUTHTOK_TYPE */
    struct pam_data *data;
    struct pam_environ *env;      /* structure to maintain environment list */
    struct _pam_fail_delay fail_delay;   /* helper function for easy delays */
    struct pam_xauth_data xauth;        /* auth info for X display */
    struct service handlers;
    struct _pam_former_state former;  /* library state - support for
					 event driven applications */
    const char *mod_name;	/* Name of the module currently executed */
    int mod_argc;               /* Number of module arguments */
    char **mod_argv;            /* module arguments */
    int choice;			/* Which function we call from the module */
};

typedef struct
{
    struct
    {
        int lanpriv:4;
        int serialpriv:4;
        int lan1priv:4;
        int lan2priv:4;
        unsigned short reserved; //for padding revanth added
    }ipmi;
    int PreferredShell;
	int Extendedprivilege;
}usrpriv_t;


extern int DoPAMAuthentication(pam_handle_t **pamh, char* username,char* userpasswd, usrpriv_t* userpriv, char *service, char *RemoteIPAddr,char *BMCIPAddr);
int GetUsrLANChPriv(usrpriv_t *usrpriv, unsigned char *IPAddr);
int inet_pton(int af, const char *src, void *dst);
]]
