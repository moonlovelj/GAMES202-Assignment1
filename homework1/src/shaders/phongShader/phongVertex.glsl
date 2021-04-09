#define MAX_LIGHT_NUM 10

attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uLightMVP;
uniform mat4 uLightMVPArray[MAX_LIGHT_NUM];
uniform highp int uActiveLightNum;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec4 vPositionFromLight;
varying vec4 vPositionFromLightArray[MAX_LIGHT_NUM];

void main(void) {

  vFragPos = (uModelMatrix * vec4(aVertexPosition, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);

  vTextureCoord = aTextureCoord;
  vPositionFromLight = uLightMVP * vec4(aVertexPosition, 1.0);
  for(int i=0; i < MAX_LIGHT_NUM; i++){
    if (i >= uActiveLightNum) break;
    vPositionFromLightArray[i] = uLightMVPArray[i] * vec4(aVertexPosition, 1.0);
  }
}