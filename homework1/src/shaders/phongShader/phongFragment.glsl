#ifdef GL_ES
precision mediump float;
#endif

#define MAX_LIGHT_NUM 10

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uLightPosArray[MAX_LIGHT_NUM];
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;
uniform vec3 uLightIntensityArray[MAX_LIGHT_NUM];
uniform highp int uActiveLightNum;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 32
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define SHADOW_MAP_RESOLUTION 2048
#define LIGHT_WIDTH 50.0

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

//uniform sampler2D uShadowMap;
uniform sampler2D uShadowMapArray[MAX_LIGHT_NUM];

varying vec4 vPositionFromLight;
varying vec4 vPositionFromLightArray[MAX_LIGHT_NUM];

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver, float filterSearchSize) {
	//uniformDiskSamples(uv);
	poissonDiskSamples(uv);
  // STEP 1: avgblocker depth
  float avgDepth = 0.0;
  int blockNum=0;
  for( int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i ++ ) {
    float shadowDepth = unpack(texture2D(shadowMap, poissonDisk[i]*filterSearchSize/float(SHADOW_MAP_RESOLUTION)+uv));
    if (shadowDepth < EPS) shadowDepth = 1.0;
    if (shadowDepth + EPS < zReceiver){
        avgDepth+=shadowDepth;
        ++blockNum;
    }
  }
  if (blockNum == 0){
    return -1.0;
  }
  avgDepth/=float(blockNum);
  avgDepth=clamp(avgDepth,0.0,1.0);
  return avgDepth;
}

float PCF(sampler2D shadowMap, vec4 coords, float fliterSize) {
  vec3 shadowMapTexCoord = coords.xyz*0.5+0.5;
  //uniformDiskSamples(coords.xy);
  poissonDiskSamples(coords.xy);

  float visibility = 0.0;
  for( int i = 0; i < PCF_NUM_SAMPLES; i ++ ) {
    float shadowDepth = unpack(texture2D(shadowMap, poissonDisk[i]*fliterSize/float(SHADOW_MAP_RESOLUTION)+shadowMapTexCoord.xy));
    if (shadowDepth < EPS) shadowDepth = 1.0;
    if (shadowMapTexCoord.z < shadowDepth + EPS){
      visibility += 1.0;
    }
  }

  visibility/=float(PCF_NUM_SAMPLES);

  return visibility;
}

float PCSS(sampler2D shadowMap, vec4 coords, float filterSearchSize){
  vec3 shadowMapTexCoord = coords.xyz*0.5+0.5;
  
  // STEP 1: avgblocker depth
  float avgDepth = findBlocker(shadowMap, shadowMapTexCoord.xy, shadowMapTexCoord.z, filterSearchSize);
  if (avgDepth < -EPS){
    return 1.0;
  }

  // STEP 2: penumbra size
  float penumbra = (shadowMapTexCoord.z-avgDepth)/avgDepth*LIGHT_WIDTH;
  penumbra = clamp(penumbra, 0.0, float(SHADOW_MAP_RESOLUTION));

  // STEP 3: filtering
  //uniformDiskSamples(coords.xy);
  poissonDiskSamples(coords.xy);
  float visibility = 0.0;
  for( int i = 0; i < PCF_NUM_SAMPLES; i ++ ) {
    float shadowDepth = unpack(texture2D(shadowMap, poissonDisk[i]*penumbra*0.5/float(SHADOW_MAP_RESOLUTION)+shadowMapTexCoord.xy));
    if (shadowDepth < EPS) shadowDepth = 1.0;
    if (shadowMapTexCoord.z < shadowDepth + EPS){
      visibility += 1.0;
    }
  }

  visibility/=float(PCF_NUM_SAMPLES);
  
  return visibility;
}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  vec3 shadowTexCoord = shadowCoord.xyz*0.5+0.5;
  float shadowDepth = unpack(texture2D(shadowMap, shadowTexCoord.xy));
  if (shadowTexCoord.z < shadowDepth+EPS){
    return 1.0;
  }
  return 0.0;
}

vec3 blinnPhong(vec3 lightPos, vec3 lightIntensity) {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(lightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      lightIntensity / pow(length(lightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility = 0.0;
  //visibility = useShadowMap(uShadowMap, vec4(vPositionFromLight.xyz/vPositionFromLight.w, 1.0));
  //visibility = PCF(uShadowMap, vec4(vPositionFromLight.xyz/vPositionFromLight.w, 1.0), 8.0);
  //visibility = PCSS(uShadowMap, vec4(vPositionFromLightArray[0].xyz/vPositionFromLightArray[0].w, 1.0), 4.0);

  vec3 phongColor = vec3(0.0, 0.0, 0.0);
  for(int i=0; i < MAX_LIGHT_NUM; i++){
    if (i >= uActiveLightNum) break;
    phongColor += blinnPhong(uLightPosArray[i], uLightIntensityArray[i]);
    visibility += PCSS(uShadowMapArray[i], vec4(vPositionFromLightArray[i].xyz/vPositionFromLightArray[i].w, 1.0), 4.0);
  }
  
  visibility /= float(uActiveLightNum);

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
  //gl_FragColor = vec4(float(uActiveLightNum),float(uActiveLightNum),float(uActiveLightNum), 1.0);
}