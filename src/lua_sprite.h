#ifndef _LUA_SPRITE_H_
#define _LUA_SPRITE_H_

#include "lua_tbl.h"

LUA_METHOD(CreateSpriteImpl);

// Lua Sprite API from C
LUA_METHOD(CreateSprite);
LUA_METHOD(UpdateSprite);
LUA_METHOD(DrawSprite);

LUA_CLASS(Get, Sprite, Position);
LUA_CLASS(Get, Sprite, Scale);
LUA_CLASS(Get, Sprite, Width);
LUA_CLASS(Get, Sprite, Height);
LUA_CLASS(Get, Sprite, Angle);
LUA_CLASS(Get, Sprite, Radians);
LUA_CLASS(Get, Sprite, Visible);
LUA_CLASS(Get, Sprite, Opacity);
LUA_CLASS(Get, Sprite, FrameDelay);
LUA_CLASS(Get, Sprite, StartFrame);
LUA_CLASS(Get, Sprite, EndFrame);
LUA_CLASS(Get, Sprite, CurrentFrame);
LUA_CLASS(Get, Sprite, Rect);
LUA_CLASS(Get, Sprite, AnimComplete);
LUA_CLASS(Set, Sprite, Position);
LUA_CLASS(Set, Sprite, Scale);
LUA_CLASS(Set, Sprite, Angle);
LUA_CLASS(Set, Sprite, Radians);
LUA_CLASS(Set, Sprite, Visible);
LUA_CLASS(Set, Sprite, Opacity);
LUA_CLASS(Set, Sprite, FrameDelay);
LUA_CLASS(Set, Sprite, Frames);
LUA_CLASS(Set, Sprite, CurrentFrame);
LUA_CLASS(Set, Sprite, Rect);
LUA_CLASS(Set, Sprite, Loop);
LUA_CLASS(Set, Sprite, AnimComplete);

#endif
