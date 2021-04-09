class PhongMaterial extends Material {

    constructor(color, specular, lights, translate, scale, vertexShader, fragmentShader) {

        let lightMVP = new glMatrix.ARRAY_TYPE(16*lights.length);
        let lightMVPIndex=0;
        let lightIntensity = [];
        let lightPos = [];
        let lightNum = lights.length;
        let shadowMap = [];
        lights.forEach(element => {
            let lMvp = element.entity.CalcLightMVP(translate, scale);
            for(let i=0; i < 16; i++){
                lightMVP[lightMVPIndex]=lMvp[i];
                ++lightMVPIndex;
            }

            lightIntensity = lightIntensity.concat(element.entity.mat.GetIntensity());
            lightPos = lightPos.concat(element.entity.lightPos);
            shadowMap = shadowMap.concat(element.entity.fbo);
        });

        super({
            // Phong
            'uSampler': { type: 'texture', value: color },
            'uKs': { type: '3fv', value: specular },
            'uLightIntensityArray': { type: '3fv', value: lightIntensity },
            // Shadow
            'uShadowMapArray': { type: 'texturev', value: shadowMap },
            'uLightMVPArray': { type: 'matrix4fv', value: lightMVP },
            'uLightPosArray': { type: '3fv', value: lightPos },
            'uActiveLightNum': { type: '1i', value: lightNum },

        }, [], vertexShader, fragmentShader);
    }
}

async function buildPhongMaterial(color, specular, lights, translate, scale, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PhongMaterial(color, specular, lights, translate, scale, vertexShader, fragmentShader);

}