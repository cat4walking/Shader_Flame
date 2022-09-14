// This shader adds tessellation in URP
Shader "ART/Unlit_Tesselation"
{
    
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _Tess("Tessellation", Range(1, 32)) = 20
        _HeightWeight("Tessellation", Range(0, 1)) = 0
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _ParallaxMap("Height Map", 2D) = "white" {}
        _BumpMap("Height Map", 2D) = "white" {}
        _BaseMap ("Albedo (RGB) Alpha (A)", 2D) = "white" {}
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
    }
 
        // The SubShader block containing the Shader code. 
        SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
 
        Pass
    {
        Tags{ "LightMode" = "UniversalForward" }
        Cull [_CullOff]
 
 
        // The HLSL code block. Unity SRP uses the HLSL language.
        HLSLPROGRAM
        // The Core.hlsl file contains definitions of frequently used HLSL
        // macros and functions, and also contains #include references to other
        // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"   
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl" 
 
 
        #pragma require tessellation
        #pragma vertex TessellationVertexProgram
        #pragma hull hull
        #pragma domain domain
        #pragma fragment frag
        
        #include "Includes/UnlitInputTesselation.hlsl"

        half4 _BaseColor;
        half _Cutoff;
        TEXTURE2D(_ParallaxMap);        SAMPLER(sampler_ParallaxMap);
 
 
    // pre tesselation vertex program
    ControlPoint TessellationVertexProgram(Attributes v)
    {
        ControlPoint p;
 
        p.vertex = v.vertex;
        p.uv = v.uv;
        p.normal = v.normal;
        p.color = v.color;
 
        return p;
    }
 
    // after tesselation
    Varyings vert(Attributes input)
    {
        Varyings output;

        // Displacement 
        half3 displacement = _ParallaxMap.SampleLevel(sampler_ParallaxMap, input.uv.xy, 0).rgb;
        half3 normal = _BumpMap.SampleLevel(sampler_BumpMap, input.uv.xy, 0).rgb;
        displacement = (displacement - 0.5) * _HeightWeight / 10;

        input.vertex.xyz += input.normal.xyz * normal.xyz * displacement;
        
        // // Displacement 
        // half3 displacement = _ParallaxMap.SampleLevel(sampler_ParallaxMap, input.uv.xy, 0).rgb;
        // displacement = (displacement - 0.5) * _HeightWeight / 10;
        // input.vertex.xyz += input.normal.xyz * displacement;
        
        output.vertex = TransformObjectToHClip(input.vertex.xyz);
        output.color = input.color;
        output.normal = input.normal;
        output.uv = input.uv;
        return output;
    }
 
    [UNITY_domain("tri")]
    Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
    {
        Attributes output;
 
#define DomainPos(fieldName) output.fieldName = \
                patch[0].fieldName * barycentricCoordinates.x + \
                patch[1].fieldName * barycentricCoordinates.y + \
                patch[2].fieldName * barycentricCoordinates.z;
 
            DomainPos(vertex)
            DomainPos(uv)
            DomainPos(color)
            DomainPos(normal)

            //Phong
            float3 pp[3]; 
            for (int i = 0; i < 3; ++i)
                pp[i] = output.vertex.xyz - patch[i].normal * (dot(output.vertex.xyz, patch[i].normal) - dot(patch[i].vertex.xyz, patch[i].normal));
            
            float3 displacedPosition = pp[0] * barycentricCoordinates.x + pp[1] * barycentricCoordinates.y + pp[2] * barycentricCoordinates.z;
            output.vertex.xyz = lerp(output.vertex.xyz, displacedPosition, 0.5);
 
            return vert(output);
    }
 
    // The fragment shader definition.            
    half4 frag(Varyings IN) : SV_Target
    {
        half alpha = SampleAlbedoAlpha(IN.uv.xy, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a;
        clip(alpha - _Cutoff);
        return half4(_BaseColor.rgb, 1.0);
    }
        ENDHLSL
    }
    }
}