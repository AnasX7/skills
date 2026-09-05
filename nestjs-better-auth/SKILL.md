---
name: nestjs-better-auth
description: "Use when integrating Better Auth (>=1.5.0) with NestJS through @thallesp/nestjs-better-auth, including body-parser setup, guards, sessions, RBAC, permissions, hooks, GraphQL, WebSockets, Fastify, and AuthService."
---

# NestJS Better Auth Integration

**Comprehensive integration of [Better Auth](https://www.better-auth.com/) for NestJS applications using [@thallesp/nestjs-better-auth](https://www.npmjs.com/package/@thallesp/nestjs-better-auth).**

**REQUIRED:** Better Auth >= 1.5.0. Older versions are deprecated and unsupported.

---

## Quick Reference

| Package      | `@thallesp/nestjs-better-auth`             |
| ------------ | ------------------------------------------ |
| Install      | `npm install better-auth @thallesp/nestjs-better-auth` |
| Body Parser  | **MUST disable** in `main.ts`              |
| Global Guard | Enabled by default (all routes protected)  |
| Fastify      | Supported with parser/CORS caveats         |

---

## Setup

### 1. Disable Body Parser (Required)

```ts
// main.ts
import { NestFactory } from '@nestjs/core'
import { AppModule } from './app.module'

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bodyParser: false, // Library re-adds default parsers automatically
  })
  await app.listen(process.env.PORT ?? 3333)
}
bootstrap()
```

### 2. Import AuthModule

```ts
// app.module.ts
import { Module } from '@nestjs/common'
import { AuthModule } from '@thallesp/nestjs-better-auth'
import { auth } from './auth'

@Module({
  imports: [
    AuthModule.forRoot({
      auth,
      bodyParser: {
        json: { enabled: true },
        urlencoded: { enabled: true, extended: true },
        rawBody: true,
      },
    }),
  ],
})
export class AppModule {}
```

The module re-adds JSON and URL-encoded parsers for non-auth routes by default. `bodyParser.json` and `bodyParser.urlencoded` accept parser options plus an optional `enabled` flag. Set `bodyParser.rawBody: true` when webhook verification or another integration needs `req.rawBody`.

Because Nest's built-in parser is disabled, `rawBody: true` passed to `NestFactory.create()` has no effect; configure it through `AuthModule.forRoot()` instead. On Fastify, `urlencoded: { extended: true }` requires the optional `qs` peer dependency for nested form parsing.

---

## Module Options

```ts
AuthModule.forRoot({
  auth,
  disableTrustedOriginsCors: false, // Disable auto CORS for trustedOrigins
  bodyParser: {
    json: { enabled: true },
    urlencoded: { enabled: true, extended: true },
    rawBody: false,
  },
  // Deprecated: prefer bodyParser.json/urlencoded.enabled
  disableBodyParser: false,
  // Deprecated: prefer bodyParser.rawBody
  enableRawBodyParser: false,
  disableGlobalAuthGuard: false, // Disable global guard (apply per route)
  disableControllers: false, // Handle routes manually
  middleware: (req, res, next) => {
    // Optional wrapper (e.g., MikroORM)
    RequestContext.create(orm.em, next)
  },
})
```

| Option | Default | Use |
| --- | --- | --- |
| `disableTrustedOriginsCors` | `false` | Disable automatic Better Auth CORS for configured `trustedOrigins`. |
| `bodyParser` | Re-adds JSON and URL-encoded parsers | Configure parser options, per-parser `enabled`, and `rawBody`. |
| `disableBodyParser` | `false` | Deprecated. Prefer `bodyParser.json.enabled` and `bodyParser.urlencoded.enabled`. |
| `enableRawBodyParser` | `false` | Deprecated. Prefer `bodyParser.rawBody`. |
| `disableGlobalAuthGuard` | `false` | Stop registering the global `AuthGuard`; apply it manually or through `APP_GUARD`. |
| `disableControllers` | `false` | Do not register the library's controllers when routes are handled manually. |
| `middleware` | `undefined` | Wrap the Better Auth handler with `(req, res, next)`, useful for request-scoped libraries such as MikroORM. |

If `disableBodyParser: true` is still used, both parsers are disabled unless explicitly re-enabled in `bodyParser`.

---

## Fastify and CORS

When `trustedOrigins` is configured, the module applies Better Auth CORS headers to auth routes. On Fastify, Better Auth routes are mounted through middleware, so application-level `@fastify/cors` does not fully cover them.

The automatic Fastify CORS fallback supports array-based `trustedOrigins`. Function-based `trustedOrigins` remain unsupported by that fallback; set `disableTrustedOriginsCors: true` and manage auth-route CORS yourself in that case.

---

## Route Protection

**Default:** All routes protected globally. Use decorators to override:

The global guard applies to REST routes and GraphQL resolvers/mutations. GraphQL uses the same `@AllowAnonymous()` and `@OptionalAuth()` overrides.

| Decorator           | Effect                                              |
| ------------------- | --------------------------------------------------- |
| `@AllowAnonymous()` | No authentication required                          |
| `@OptionalAuth()`   | Auth optional, session may be null                  |

**Apply to class or method:**

```ts
@AllowAnonymous() // All routes in controller are public
@Controller('public')
export class PublicController {}

@Roles(['admin']) // All routes require admin role
@Controller('admin')
export class AdminController {}
```

### WebSocket Protection

WebSockets are supported, but you must manually apply `@UseGuards(AuthGuard)` at the Gateway or Message level. `@AllowAnonymous()` and `@OptionalAuth()` can then override authentication requirements.

```ts
@WebSocketGateway({ path: '/ws', namespace: 'test' })
@UseGuards(AuthGuard)
export class TestGateway {}
```

---

## Decorators

### Session Access

```ts
import { Session, UserSession } from "@thallesp/nestjs-better-auth";

@Get("me")
async getProfile(@Session() session: UserSession) {
  return session;
}
```

### Role-Based Access Control

Use separate decorators for system-level and organization-level authorization:

| Decorator | Checks | Use Case |
| --------- | ------ | -------- |
| `@Roles([...])` | `user.role` only | System-level roles via Better Auth admin plugin |
| `@RequireActiveOrg()` | `session.activeOrganizationId` | Routes that only need active organization context |
| `@OrgRoles([...])` | Active organization plus member role | Org-scoped roles via Better Auth organization plugin |

**IMPORTANT:** These decorators are intentionally separate to prevent privilege escalation.
`@Roles()` checks only `user.role` (system roles) and does not check organization member roles.

#### `@Roles()` - System-Level Roles

Use for system-wide admin protection from Better Auth's admin plugin:

```ts
import { Controller, Get } from '@nestjs/common'
import { Roles } from '@thallesp/nestjs-better-auth'

@Controller('admin')
export class AdminController {
  @Roles(['admin'])
  @Get('dashboard')
  async adminDashboard() {
    // Requires user.role = 'admin'
    // Organization admins cannot access this route unless they are system admins
    return { message: 'System admin dashboard' }
  }
}

// Or as a class decorator
@Roles(['admin'])
@Controller('admin')
export class AdminRoutesController {}
```

#### `@RequireActiveOrg()` - Active Organization Only

Use `@RequireActiveOrg()` when a route needs an authenticated user with an active organization but does not require a specific member role:

```ts
import { Controller, Get } from '@nestjs/common'
import { RequireActiveOrg, Session, UserSession } from '@thallesp/nestjs-better-auth'

@RequireActiveOrg()
@Controller('projects')
export class ProjectsController {
  @Get()
  listProjects(@Session() session: UserSession) {
    return { orgId: session.session.activeOrganizationId }
  }
}
```

#### `@OrgRoles()` - Organization-Level Roles

Use for org-scoped protection. Requires active organization context (`activeOrganizationId`):

```ts
import { Controller, Get } from '@nestjs/common'
import { OrgRoles, Session, UserSession } from '@thallesp/nestjs-better-auth'

@Controller('org')
export class OrgController {
  @OrgRoles(['owner', 'admin'])
  @Get('settings')
  async getOrgSettings(@Session() session: UserSession) {
    // Requires active org + member role owner/admin
    return { orgId: session.session.activeOrganizationId }
  }

  @OrgRoles(['owner'])
  @Get('billing')
  async getOrgBilling() {
    return { message: 'Billing settings' }
  }
}
```

`@RequireActiveOrg()` and `@OrgRoles()` require active organization context. Both role decorators accept any role strings you define. Organization defaults are typically
`owner`, `admin`, and `member` unless customized in Better Auth organization plugin config.

### Permission-Based Access Control

Use @UserHasPermission() for system-level permissions configured through Better Auth's admin plugin. Use @MemberHasPermission() for organization-member permissions configured through the organization plugin; it requires an active organization.

~~~~ts
import { Controller, Post } from '@nestjs/common'
import {
  MemberHasPermission,
  UserHasPermission,
} from '@thallesp/nestjs-better-auth'

@Controller('projects')
export class ProjectController {
  @UserHasPermission({
    permission: { project: ['create', 'update'] },
  })
  @Post()
  createProject() {}

  @UserHasPermission({
    permissions: { project: ['delete'], sale: ['create'] },
  })
  @Post(':id/delete')
  deleteProject() {}

  @MemberHasPermission({
    permissions: { project: ['create', 'update'] },
  })
  @Post('organization')
  createOrganizationProject() {}
}
~~~~

@UserHasPermission() accepts a single permission, multiple permissions, an optional server-only role, and an optional userId (defaulting to the current user). @MemberHasPermission() requires permissions matching the organization's access-control statement.

### Request Object Access

```ts
@Get("me")
async getProfile(@Request() req: ExpressRequest) {
  return {
    session: req.session,  // Full session object
    user: req.user,        // User from session
  };
}
```

---

## AuthService

Inject to access Better Auth API with type safety:

```ts
import { AuthService } from '@thallesp/nestjs-better-auth'
import { fromNodeHeaders } from 'better-auth/node'
import { auth } from '../auth'

@Controller('users')
export class UsersController {
  constructor(private authService: AuthService<typeof auth>) {}

  @Get('accounts')
  async getAccounts(@Request() req: ExpressRequest) {
    return this.authService.api.listUserAccounts({
      headers: fromNodeHeaders(req.headers),
    })
  }

  @Post('api-keys')
  async createApiKey(@Request() req: ExpressRequest, @Body() body) {
    // Plugin methods (e.g., createApiKey) require AuthService<typeof auth>
    return this.authService.api.createApiKey({
      ...body,
      headers: fromNodeHeaders(req.headers),
    })
  }
}
```

---

## Hooks

**REQUIRED:** Set `hooks: {}` (empty object) in your Better Auth config to enable hook decorators.

```ts
// auth.ts
export const auth = betterAuth({
  basePath: '/api/auth',
  hooks: {}, // Minimum required for @Hook decorators
})
```

**Creating hooks:**

```ts
import { Injectable } from '@nestjs/common'
import {
  Hook,
  BeforeHook,
  AfterHook,
  AuthHookContext,
} from '@thallesp/nestjs-better-auth'

@Hook()
@Injectable()
export class SignUpHook {
  constructor(private readonly signUpService: SignUpService) {}

  @BeforeHook('/sign-up/email')
  async handle(ctx: AuthHookContext) {
    await this.signUpService.execute(ctx)
  }
}
```

**Register in module:**

```ts
@Module({
  imports: [AuthModule.forRoot({ auth })],
  providers: [SignUpHook, SignUpService],
})
export class AppModule {}
```

---

## Database Hook Decorators

Set databaseHooks: {} in betterAuth() before using database lifecycle decorators:

~~~~ts
export const auth = betterAuth({
  databaseHooks: {},
})
~~~~

Use @DatabaseHook() with @BeforeCreate, @AfterCreate, @BeforeUpdate, @AfterUpdate, @BeforeDelete, or @AfterDelete. Supported models are user, session, account, and verification.

~~~~ts
import { Injectable } from '@nestjs/common'
import {
  AfterCreate,
  BeforeCreate,
  DatabaseHook,
} from '@thallesp/nestjs-better-auth'

@DatabaseHook()
@Injectable()
export class UserCreateHook {
  @BeforeCreate('user')
  beforeUserCreate(user) {
    return {
      data: {
        ...user,
        displayName: user.name.trim(),
      },
    }
  }

  @AfterCreate('user')
  async afterUserCreate(user) {
    // Use after hooks for side effects such as sending a welcome email.
  }
}
~~~~

Before hooks may return false to abort an operation or { data: ... } to modify data. After hooks are for side effects.

---

## Common Gotchas

1. **Body parser** - MUST disable it in `main.ts` or Better Auth requests can fail.
2. **Raw body** - Configure `bodyParser.rawBody`; `rawBody: true` in `NestFactory.create()` has no effect once Nest parsing is disabled.
3. **Global guard** - REST and GraphQL are protected by default; use `@AllowAnonymous()` or `@OptionalAuth()` as needed.
4. **WebSocket** - Add `@UseGuards(AuthGuard)` at the Gateway or Message level.
5. **Hook config** - `hooks: {}` is required for hook decorators and `databaseHooks: {}` is required for database hook decorators.
6. **Permission config** - Configure the matching Better Auth admin or organization access-control plugin before using permission decorators.
7. **Organization context** - `@RequireActiveOrg()`, `@OrgRoles()`, and `@MemberHasPermission()` require an active organization.
8. **Plugin types** - Use `AuthService<typeof auth>` for type-safe plugin method access.
9. **Fastify** - Install `qs` for nested URL-encoded parsing with `extended: true`; function-based `trustedOrigins` are not supported by the automatic Fastify CORS fallback.
10. **Deprecated options** - Prefer `bodyParser.json.enabled`, `bodyParser.urlencoded.enabled`, and `bodyParser.rawBody` over `disableBodyParser` and `enableRawBodyParser`.

---

## Imports Summary

```ts
// Main imports
import {
  AuthModule,
  AuthService,
  AuthGuard,
} from '@thallesp/nestjs-better-auth'

// Decorators
import {
  Session,
  UserSession,
  AllowAnonymous,
  OptionalAuth,
  Roles,
  RequireActiveOrg,
  OrgRoles,
  UserHasPermission,
  MemberHasPermission,
} from '@thallesp/nestjs-better-auth'

// Hooks
import {
  Hook,
  BeforeHook,
  AfterHook,
  AuthHookContext,
  DatabaseHook,
  BeforeCreate,
  AfterCreate,
  BeforeUpdate,
  AfterUpdate,
  BeforeDelete,
  AfterDelete,
} from '@thallesp/nestjs-better-auth'
```

---

## Resources

- [npm Package](https://www.npmjs.com/package/@thallesp/nestjs-better-auth)
- [Better Auth Docs](https://www.better-auth.com/docs)
