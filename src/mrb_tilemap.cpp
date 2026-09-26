/**
 * @file mrb_tilemap.cpp
 * @brief Tilemap 클래스 (mruby). lua_tilemap.cpp 에 대응한다.
 *
 *   map = Tilemap.new(path)    # 실패하면 RuntimeError (메시지는 로더의 lastError)
 *   map = Tilemap.load(path)   # 실패하면 nil (프렐류드)
 *   map.draw(layer_from, layer_to, cam_x = 0, cam_y = 0)
 *   map.width, map.height, map.tile_width, map.tile_height, map.layer_count
 *   map.size -> [width, height, tile_width, tile_height, layer_count]
 *   map.tile_id(x, y, layer) -> gid (범위 밖은 0)
 *   map.set_tile_id(x, y, layer, gid) -> true/false
 *   map.passable?(x, y)
 *   map.dispose, map.disposed?
 *
 * 좌표 규약: x, y 는 0 기준 타일 좌표. **layer 도 0 기준이다** (Ruby 배열 관례.
 * Lua 바인딩은 1 기준이다). cam_x, cam_y 는 월드 픽셀.
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "Tilemap.h"

#include <string>

namespace
{
	void TilemapFree(mrb_state* mrb, void* ptr)
	{
		delete static_cast<Initial2D::Tilemap*>(ptr);
	}

	const mrb_data_type TilemapType = { "Tilemap", TilemapFree };

	Initial2D::Tilemap* GetTilemap(mrb_state* mrb, mrb_value self)
	{
		Initial2D::Tilemap* p = static_cast<Initial2D::Tilemap*>(mrb_data_get_ptr(mrb, self, &TilemapType));
		if (p == nullptr)
		{
			mrb_raise(mrb, E_RUNTIME_ERROR, "disposed Tilemap");
		}
		return p;
	}

	mrb_value tilemap_initialize(mrb_state* mrb, mrb_value self)
	{
		const char* path = nullptr;
		mrb_get_args(mrb, "z", &path);

		if (DATA_PTR(self) != nullptr)
		{
			TilemapFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}

		Initial2D::Tilemap* p = new Initial2D::Tilemap();
		if (!p->load(path))
		{
			const std::string error = p->lastError();
			delete p;
			mrb_raise(mrb, E_RUNTIME_ERROR, error.c_str());
		}

		DATA_TYPE(self) = &TilemapType;
		DATA_PTR(self) = p;
		return self;
	}

	mrb_value tilemap_draw(mrb_state* mrb, mrb_value self)
	{
		mrb_int from = 0, to = 0, camX = 0, camY = 0;
		mrb_get_args(mrb, "ii|ii", &from, &to, &camX, &camY);
		GetTilemap(mrb, self)->draw(static_cast<int>(from), static_cast<int>(to),
			static_cast<int>(camX), static_cast<int>(camY));
		return self;
	}

	mrb_value tilemap_width(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetTilemap(mrb, self)->width());
	}

	mrb_value tilemap_height(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetTilemap(mrb, self)->height());
	}

	mrb_value tilemap_tile_width(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetTilemap(mrb, self)->tileWidth());
	}

	mrb_value tilemap_tile_height(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetTilemap(mrb, self)->tileHeight());
	}

	mrb_value tilemap_layer_count(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetTilemap(mrb, self)->layerCount());
	}

	mrb_value tilemap_size(mrb_state* mrb, mrb_value self)
	{
		Initial2D::Tilemap* p = GetTilemap(mrb, self);
		mrb_value tuple = mrb_ary_new_capa(mrb, 5);
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, p->width()));
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, p->height()));
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, p->tileWidth()));
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, p->tileHeight()));
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, p->layerCount()));
		return tuple;
	}

	mrb_value tilemap_tile_id(mrb_state* mrb, mrb_value self)
	{
		mrb_int x = 0, y = 0, layer = 0;
		mrb_get_args(mrb, "iii", &x, &y, &layer);
		return mrb_int_value(mrb, GetTilemap(mrb, self)->getTileId(
			static_cast<int>(x), static_cast<int>(y), static_cast<int>(layer)));
	}

	mrb_value tilemap_set_tile_id(mrb_state* mrb, mrb_value self)
	{
		mrb_int x = 0, y = 0, layer = 0, gid = 0;
		mrb_get_args(mrb, "iiii", &x, &y, &layer, &gid);
		return mrb_bool_value(GetTilemap(mrb, self)->setTileId(
			static_cast<int>(x), static_cast<int>(y), static_cast<int>(layer), static_cast<int>(gid)));
	}

	mrb_value tilemap_passable(mrb_state* mrb, mrb_value self)
	{
		mrb_int x = 0, y = 0;
		mrb_get_args(mrb, "ii", &x, &y);
		return mrb_bool_value(GetTilemap(mrb, self)->isPassable(static_cast<int>(x), static_cast<int>(y)));
	}

	mrb_value tilemap_dispose(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &TilemapType);
		if (DATA_PTR(self) != nullptr)
		{
			TilemapFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}
		return mrb_nil_value();
	}

	mrb_value tilemap_disposed(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &TilemapType);
		return mrb_bool_value(DATA_PTR(self) == nullptr);
	}
}

void MRuby_DefineTilemap(mrb_state* mrb)
{
	struct RClass* cls = mrb_define_class(mrb, "Tilemap", mrb->object_class);
	MRB_SET_INSTANCE_TT(cls, MRB_TT_DATA);

	mrb_define_method(mrb, cls, "initialize", tilemap_initialize, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "draw", tilemap_draw, MRB_ARGS_ARG(2, 2));
	mrb_define_method(mrb, cls, "width", tilemap_width, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "height", tilemap_height, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "tile_width", tilemap_tile_width, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "tile_height", tilemap_tile_height, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "layer_count", tilemap_layer_count, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "size", tilemap_size, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "tile_id", tilemap_tile_id, MRB_ARGS_REQ(3));
	mrb_define_method(mrb, cls, "set_tile_id", tilemap_set_tile_id, MRB_ARGS_REQ(4));
	mrb_define_method(mrb, cls, "passable?", tilemap_passable, MRB_ARGS_REQ(2));
	mrb_define_method(mrb, cls, "dispose", tilemap_dispose, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "disposed?", tilemap_disposed, MRB_ARGS_NONE());
}

#endif // INITIAL2D_HAS_MRUBY
