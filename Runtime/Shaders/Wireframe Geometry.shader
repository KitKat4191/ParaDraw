// Unity Wireframe Shaders by Chaser324 licensed under MIT
// https://github.com/Chaser324/unity-wireframe/blob/1854d0aceec52351b3bb8e544d5fec9ecf688bef/Assets/Wireframe/Shaders/WireframeShaded-Unlit.shader
Shader "Orchid Seal/ParaDraw/Wireframe Geometry"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		[PerRendererData] _WireThickness("Wire Thickness", RANGE(0, 800)) = 100
		_WireSmoothness("Wire Smoothness", RANGE(0, 20)) = 3
		[PerRendererData] _WireColor("Wire Color", Color) = (0.0, 1.0, 0.0, 1.0)
		_BaseColor("Base Color", Color) = (0.0, 0.0, 0.0, 1.0)
		_Cutoff("Alpha cutoff", Range(0.15, 0.85)) = 0.4
		_DepthOffset("Depth offset", Range(0, 0.001)) = 0.00001
	}

	SubShader
	{
		Tags
		{
			"IgnoreProjector" = "True"
			"Queue" = "AlphaTest"
			"RenderType" = "TransparentCutout"
		}

		Pass
		{
			// Wireframe shader based on the the following
			// http://developer.download.nvidia.com/SDK/10/direct3d/Source/SolidWireframe/Doc/SolidWireframe.pdf

			AlphaToMask On
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "UnityCG.cginc"

			uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
			uniform float _WireThickness;
			uniform float _WireSmoothness;
			uniform float4 _WireColor;
			uniform float4 _BaseColor;
			fixed _Cutoff;
			float _DepthOffset;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord0 : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2g
			{
				float4 projectionSpaceVertex : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float4 worldSpacePosition : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			struct g2f
			{
				float4 projectionSpaceVertex : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float4 worldSpacePosition : TEXCOORD1;
				float4 dist : TEXCOORD2;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2g vert(appdata v)
			{
				v2g o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 positionCs = UnityObjectToClipPos(v.vertex);

#if defined(UNITY_REVERSED_Z)
				positionCs.z += _DepthOffset * positionCs.w;
#else
				positionCs.z -= _DepthOffset * positionCs.w;
#endif

				o.projectionSpaceVertex = positionCs;
				o.worldSpacePosition = mul(unity_ObjectToWorld, v.vertex);
				o.uv0 = TRANSFORM_TEX(v.texcoord0, _MainTex);
				return o;
			}

			[maxvertexcount(3)]
			void geom(triangle v2g i[3], inout TriangleStream<g2f> triangleStream)
			{
				float2 p0 = i[0].projectionSpaceVertex.xy / i[0].projectionSpaceVertex.w;
				float2 p1 = i[1].projectionSpaceVertex.xy / i[1].projectionSpaceVertex.w;
				float2 p2 = i[2].projectionSpaceVertex.xy / i[2].projectionSpaceVertex.w;

				float2 edge0 = p2 - p1;
				float2 edge1 = p2 - p0;
				float2 edge2 = p1 - p0;

				// To find the distance to the opposite edge, we take the
				// formula for finding the area of a triangle Area = Base/2 * Height, 
				// and solve for the Height = (Area * 2)/Base.
				// We can get the area of a triangle by taking its cross product
				// divided by 2.  However we can avoid dividing our area/base by 2
				// since our cross product will already be double our area.
				float area = abs(edge1.x * edge2.y - edge1.y * edge2.x);
				float wireThickness = 800 - _WireThickness;

				g2f o;

				o.uv0 = i[0].uv0;
				o.worldSpacePosition = i[0].worldSpacePosition;
				o.projectionSpaceVertex = i[0].projectionSpaceVertex;
				o.dist.xyz = float3((area / length(edge0)), 0.0, 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[0], o);
				triangleStream.Append(o);

				o.uv0 = i[1].uv0;
				o.worldSpacePosition = i[1].worldSpacePosition;
				o.projectionSpaceVertex = i[1].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, (area / length(edge1)), 0.0) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[1], o);
				triangleStream.Append(o);

				o.uv0 = i[2].uv0;
				o.worldSpacePosition = i[2].worldSpacePosition;
				o.projectionSpaceVertex = i[2].projectionSpaceVertex;
				o.dist.xyz = float3(0.0, 0.0, (area / length(edge2))) * o.projectionSpaceVertex.w * wireThickness;
				o.dist.w = 1.0 / o.projectionSpaceVertex.w;
				UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(i[2], o);
				triangleStream.Append(o);
			}

			fixed4 frag(g2f i) : SV_Target
			{
				float minDistanceToEdge = min(i.dist[0], min(i.dist[1], i.dist[2])) * i.dist[3];

				float4 baseColor = _BaseColor * tex2D(_MainTex, i.uv0);

				// Smooth our line out
				float t = exp2(_WireSmoothness * -minDistanceToEdge * minDistanceToEdge);
				fixed4 finalColor = lerp(baseColor, _WireColor, t);
				finalColor.a = (t - _Cutoff) / max(fwidth(t), 0.0001) + 0.5;

				return finalColor;
			}
			ENDCG
		}
	}
}