using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;

namespace Editor.Core
{
    public sealed class LayerCreator
    {
        private static readonly Lazy<LayerCreator> instance = new Lazy<LayerCreator>(() => new LayerCreator());

        public static LayerCreator Instance
        {
            get { return instance.Value; }
        }

        public List<int> Create(int width, int height)
        {
            int count = width * height;
            var list = new List<int>(count);
            list.AddRange(Enumerable.Repeat(0, count));

            return list;
        }
    }

}
