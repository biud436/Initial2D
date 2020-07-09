using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace Editor.Loader
{
    class MapLoader
    {
        public static int WIDTH = 17;
        public static int HEIGHT = 13;

        private static readonly Lazy<MapLoader> instance = new Lazy<MapLoader>(() => new MapLoader());

        private MapLoader()
        {

        }

        public static MapLoader Instance
        {
            get
            {
                return instance.Value;
            }
        }

        public bool Exist(int mapId)
        {
            string root = DataManager.Instance.ProjectPath;
            string mapFileName = Path.Combine(root, "resources", "maps", $"map_{mapId}.json");

            return File.Exists(mapFileName);
        }

        public Map Load(int mapId)
        {
            Map tempMap = new Map();
            string root = DataManager.Instance.ProjectPath;
            string mapFileName = Path.Combine(root, "resources", "maps", $"map_{mapId}.json");

            // 맵 파일이 resources/maps/map_mapId.json에 존재한다면 해당 맵 JSON 파일을 로드합니다.
            if (Exist(mapId))
            {
                string contents = File.ReadAllText(mapFileName);
                tempMap = JsonConvert.DeserializeObject<Map>(contents);
            } 
            else
            {
                throw new InvalidDataException($"{mapFileName} 파일이 없습니다.");
            }

            return tempMap;
        }

        public Map CreateEmptyMap(int width, int height, int mapId)
        {
            if(!Enumerable.Range(0, Int32.MaxValue).Contains(width))
            {
                throw new InvalidProgramException("맵의 폭값이 잘못되었습니다.");
            }

            if (!Enumerable.Range(0, Int32.MaxValue).Contains(height))
            {
                throw new InvalidProgramException("맵의 높이값이 잘못되었습니다.");
            }

            return new Map(width, height, mapId);
        }
    }
}
