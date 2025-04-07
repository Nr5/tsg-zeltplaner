let ws;
let lastmessage = "";
let wasm_strbuf;
let teilnehmer_buf;
const cmd_change_zelt=0;
const cmd_grab_teilnehmer=1;
const cmd_drop_teilnehmer=2;
const cmd_anwesend=3;
const cmd_abwesend=4;
const cmd_synch=5;
const cmd_force_drop=6;
const cmd_multichange=7;
const cmd_rst_anwesenheit=8;
const cmd_request_state=9;
function i32(byte_array){
	return (byte_array[0] << 24) + (byte_array[1] << 16) + (byte_array[2] << 8) + byte_array[3]
}
function i16(byte_array){
	return (byte_array[0] << 8) + byte_array[1]
}
function messagehandler(e){
	if (e.data == lastmessage)return;
	message = new Uint8Array(e.data);
	//sb_arr[0] = 110;	
	if (message[0] == cmd_request_state){
		lastmessage=e.data;
		let offset =i32(new Uint8Array(e.data,1));
//		console.log("sb_arr: ", sb_arr[0]);
	}
	else if (message[0] == 10) {
//		console.log("get teilnehmer pointers");
	}
//	console.log(sb_arr);
/*
	if (message[0] <= cmd_abwesend){
		var teilnehmer_id = i16(message.slice(1,3))
	}
	if (message[0] == cmd_change_zelt){
		const server_checksum = i32(message.slice(5,9))
		change_zelt(teilnehmer_id, message[3], message[4],server_checksum);
	}else if (message[0] == cmd_grab_teilnehmer){
		element = document.getElementById("teilnehmerbox"+teilnehmer_id);
		if (element != null){
			element.setAttribute("grabbed", null);
			element.draggable = false;
		}
	}else if (message[0] == cmd_drop_teilnehmer){
		element = document.getElementById("teilnehmerbox"+teilnehmer_id);
		if (element != null){
			element.removeAttribute("grabbed");
			element.draggable = true;
		}
	}else if (message[0] == cmd_anwesend){
		const server_checksum = i32(message.slice(3,7))
		document.getElementById("zt"+teilnehmer_id).children[0].checked = true
		checksum ^= (message[1]<< 24) + (message[2] << 16) + 0xFF00;
		console.log("anw: ser_chsum: " + server_checksum)
		console.log("anw: cli_chsum: " + checksum)
		if (checksum != server_checksum){
			checksum = server_checksum;
			console.log("wrong checksum anw");
		}
	}else if (message[0] == cmd_abwesend){
		const server_checksum = i32(message.slice(3,7))
		document.getElementById("zt"+teilnehmer_id).children[0].checked = false
		checksum ^= (message[1]<< 24) + (message[2] << 16) + 0xFE00;
		console.log("abw: ser_chsum: " + server_checksum)
		console.log("abw: cli_chsum: " + checksum)
		if (checksum != server_checksum){
			checksum = server_checksum;
			console.log("wrong checksum abw");
		}

	}else if (message[0] == cmd_force_drop){
		el_dragimage.style["display"] = "none";
		if (draggedelement2 != null){
			draggedelement2.draggable = false;
			draggedelement2 = null;
		}
	}else if (message[0] == cmd_synch && message[1] == 255 - cmd_synch){
		location.reload(true);
	}else if (message[0] == cmd_multichange){
		console.log("multichange")
		multi_change(message);
	}
		else if (message[0] == cmd_rst_anwesenheit && message[1] == 255 - cmd_rst_anwesenheit){
		for (el of document.getElementsByClassName("zteilnehmer")){
			el.children[0].children[0].checked=false;	
		}
	}
	*/
}
function startws(sba){
	ws = new WebSocket("ws://localhost:3001/chat");
//	ws = new WebSocket("wss://beepdoop.uber.space/tsg-zeltlager");
	ws.binaryType = 'arraybuffer';
	ws.onmessage = messagehandler;
		
	ws.onclose = function(e) { 
		setTimeout( startws,1000);
	};
	ws.onopen = function(e) { 
		console.log("ws_open");
		ws.send(new Uint8Array([cmd_request_state]));
//		ws.send(new Uint8Array([cmd_synch, version>>8, version]))
		//sb_arr[0] = 100;
		//sb_arr.set(new TextEncoder("utf-8").encode("hello"),0);
	};
//	sba[0] = 112;	
}
async function dvui_sleep(ms) {
    await new Promise(r => setTimeout(r, ms));
}

async function dvui_fetch(url) {
    let x = await fetch(url);
    let blob = await x.blob();
    //console.log("dvui_fetch: " + blob.size);
    return new Uint8Array(await blob.arrayBuffer());
}

function dvui(canvasId, wasmFile) {
    const vertexShaderSource_webgl = `
        precision mediump float;

        attribute vec4 aVertexPosition;
        attribute vec4 aVertexColor;
        attribute vec2 aTextureCoord;

        uniform mat4 uMatrix;

        varying vec4 vColor;
        varying vec2 vTextureCoord;

        void main() {
          gl_Position = uMatrix * aVertexPosition;
          vColor = aVertexColor / 255.0;  // normalize u8 colors to 0-1
          vTextureCoord = aTextureCoord;
        }
    `;

    const vertexShaderSource_webgl2 = `# version 300 es

        precision mediump float;

        in vec4 aVertexPosition;
        in vec4 aVertexColor;
        in vec2 aTextureCoord;

        uniform mat4 uMatrix;

        out vec4 vColor;
        out vec2 vTextureCoord;

        void main() {
          gl_Position = uMatrix * aVertexPosition;
          vColor = aVertexColor / 255.0;  // normalize u8 colors to 0-1
          vTextureCoord = aTextureCoord;
        }
    `;


    const fragmentShaderSource_webgl = `
        precision mediump float;

        varying vec4 vColor;
        varying vec2 vTextureCoord;

        uniform sampler2D uSampler;
        uniform bool useTex;

        void main() {
            if (useTex) {
                gl_FragColor = texture2D(uSampler, vTextureCoord) * vColor;
            }
            else {
                gl_FragColor = vColor;
            }
        }
    `;

    const fragmentShaderSource_webgl2 = `# version 300 es

        precision mediump float;

        in vec4 vColor;
        in vec2 vTextureCoord;

        uniform sampler2D uSampler;
        uniform bool useTex;

        out vec4 fragColor;

        void main() {
            if (useTex) {
                fragColor = texture(uSampler, vTextureCoord) * vColor;
            }
            else {
                fragColor = vColor;
            }
        }
    `;

    let webgl2 = true;
    let gl;
    let indexBuffer;
    let vertexBuffer;
    let shaderProgram;
    let programInfo;
    const textures = new Map();
    let newTextureId = 1;
    let using_fb = false;
    let frame_buffer = null;
    let renderTargetSize = [0, 0];

    let wasmResult;
    let log_string = '';
    let hidden_input;
    let touches = [];  // list of tuple (touch identifier, initial index)
    let textInputRect = [];  // x y w h of on screen keyboard editing position, or empty if none
	let cli2ser;	
	let ser2cli;	
	let theme_ptr;
	let sb_arr;	
let version_ptr;
    //let par = document.createElement("p");
    //document.body.prepend(par);

    function oskCheck() {
        if (textInputRect.length == 0) {
            gl.canvas.focus();
        } else {
	    hidden_input.style.left = (window.scrollX + gl.canvas.getBoundingClientRect().left + textInputRect[0]) + 'px';
	    hidden_input.style.top = (window.scrollY + gl.canvas.getBoundingClientRect().top + textInputRect[1]) + 'px';
	    hidden_input.style.width = textInputRect[2] + 'px';
	    hidden_input.style.height = textInputRect[3] + 'px';
            hidden_input.focus();
    	    //par.textContent = hidden_input.style.left + " " + hidden_input.style.top + " " + hidden_input.style.width + " " + hidden_input.style.height;
        }
    }

    function touchIndex(pointerId) {
        let idx = touches.findIndex((e) => e[0] === pointerId);
        if (idx < 0) {
            idx = touches.length;
            touches.push([pointerId, idx]);
        }

        return idx;
    }

    const utf8decoder = new TextDecoder();
    const utf8encoder = new TextEncoder();

    const imports = {
        env: {
		wasm_websocket_write: (ptr, len) => {
			ws.send(new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, len));
		},
        wasm_about_webgl2: () => {
            if (webgl2) {
                return 1;
            } else {
                return 0;
            }
        },
        wasm_panic: (ptr, len) => {
            let msg = utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, len));
            alert(msg);
            throw Error(msg);
        },
        wasm_log_write: (ptr, len) => {
            log_string += utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, len));
        },
        wasm_log_flush: () => {
            console.log(log_string);
            log_string = '';
        },
        wasm_now() {
            return performance.now();
        },
        wasm_sleep(ms) {
            dvui_sleep(ms);
        },
        wasm_pixel_width() {
            return gl.drawingBufferWidth;
        },
        wasm_pixel_height() {
            return gl.drawingBufferHeight;
        },
        wasm_frame_buffer() {
	    if (using_fb)
		return 1;
	    else
		return 0;
        },
        wasm_canvas_width() {
            return gl.canvas.clientWidth;
        },
        wasm_canvas_height() {
            return gl.canvas.clientHeight;
        },
        wasm_textureCreate(pixels, width, height, interp) {
            const pixelData = new Uint8Array(wasmResult.instance.exports.memory.buffer, pixels, width * height * 4);

            const texture = gl.createTexture();
            const id = newTextureId;
            //console.log("creating texture " + id);
            newTextureId += 1;
            textures.set(id, [texture, width, height]);
          
            gl.bindTexture(gl.TEXTURE_2D, texture);

            gl.texImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RGBA,
                width,
                height,
                0,
                gl.RGBA,
                gl.UNSIGNED_BYTE,
                pixelData,
            );

            if (webgl2) {
                gl.generateMipmap(gl.TEXTURE_2D);
	    }

	    if (interp == 0) {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
	    } else {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	    }
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

	    gl.bindTexture(gl.TEXTURE_2D, null);

            return id;
        },
        wasm_textureCreateTarget(width, height, interp) {
            const texture = gl.createTexture();
            const id = newTextureId;
            //console.log("creating texture " + id);
            newTextureId += 1;
            textures.set(id, [texture, width, height]);
          
            gl.bindTexture(gl.TEXTURE_2D, texture);

            gl.texImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RGBA,
                width,
                height,
                0,
                gl.RGBA,
                gl.UNSIGNED_BYTE,
                null,
            );

	    if (interp == 0) {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
	    } else {
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	    }
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

	    gl.bindTexture(gl.TEXTURE_2D, null);

	    return id;
	},
        wasm_textureRead(textureId, pixels_out, width, height) {
	    //console.log("textureRead " + textureId);
            const texture = textures.get(textureId)[0];

	    gl.bindFramebuffer(gl.FRAMEBUFFER, frame_buffer);
	    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);

	    var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, pixels_out, width * height * 4);
	    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, dest, 0);
	
	    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
	},
	wasm_renderTarget(id) {
	    //console.log("renderTarget " + id);
	    if (id === 0) {
		using_fb = false;
	        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
		renderTargetSize = [gl.drawingBufferWidth, gl.drawingBufferHeight];
		gl.viewport(0, 0, renderTargetSize[0], renderTargetSize[1]);
		gl.scissor(0, 0, renderTargetSize[0], renderTargetSize[1]);
	    } else {
		using_fb = true;
	        gl.bindFramebuffer(gl.FRAMEBUFFER, frame_buffer);
		
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textures.get(id)[0], 0);
		renderTargetSize = [textures.get(id)[1], textures.get(id)[2]];
		gl.viewport(0, 0, renderTargetSize[0], renderTargetSize[1]);
		gl.scissor(0, 0, renderTargetSize[0], renderTargetSize[1]);
	    }
	},
        wasm_textureDestroy(id) {
            //console.log("deleting texture " + id);
            const texture = textures.get(id)[0];
            textures.delete(id);

            gl.deleteTexture(texture);
        },
        wasm_renderGeometry(textureId, index_ptr, index_len, vertex_ptr, vertex_len, sizeof_vertex, offset_pos, offset_col, offset_uv, clip, x, y, w, h) {
            //console.log("drawClippedTriangles " + textureId + " sizeof " + sizeof_vertex + " pos " + offset_pos + " col " + offset_col + " uv " + offset_uv);

	    //let old_scissor;
	    if (clip === 1) {
		// just calling getParameter here is quite slow (5-10 ms per frame according to chrome)
                //old_scissor = gl.getParameter(gl.SCISSOR_BOX);
                gl.scissor(x, y, w, h);
            }

            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
            const indices = new Uint16Array(wasmResult.instance.exports.memory.buffer, index_ptr, index_len / 2);
            gl.bufferData( gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

            gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
            const vertexes = new Uint8Array(wasmResult.instance.exports.memory.buffer, vertex_ptr, vertex_len);
            gl.bufferData( gl.ARRAY_BUFFER, vertexes, gl.STATIC_DRAW);

            let matrix = new Float32Array(16);
            matrix[0] = 2.0 / renderTargetSize[0];
            matrix[1] = 0.0;
            matrix[2] = 0.0;
            matrix[3] = 0.0;
            matrix[4] = 0.0;
	    if (using_fb) {
		matrix[5] = 2.0 / renderTargetSize[1];
	    } else {
		matrix[5] = -2.0 / renderTargetSize[1];
	    }
            matrix[6] = 0.0;
            matrix[7] = 0.0;
            matrix[8] = 0.0;
            matrix[9] = 0.0;
            matrix[10] = 1.0;
            matrix[11] = 0.0;
            matrix[12] = -1.0;
	    if (using_fb) {
                matrix[13] = -1.0;
	    } else {
                matrix[13] = 1.0;
	    }
            matrix[14] = 0.0;
            matrix[15] = 1.0;

            // vertex
            gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
            gl.vertexAttribPointer(
                programInfo.attribLocations.vertexPosition,
                2,  // num components
                gl.FLOAT,
                false,  // don't normalize
                sizeof_vertex,  // stride
                offset_pos,  // offset
            );
            gl.enableVertexAttribArray(programInfo.attribLocations.vertexPosition);

            // color
            gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
            gl.vertexAttribPointer(
                programInfo.attribLocations.vertexColor,
                4,  // num components
                gl.UNSIGNED_BYTE,
                false,  // don't normalize
                sizeof_vertex, // stride
                offset_col,  // offset
            );
            gl.enableVertexAttribArray(programInfo.attribLocations.vertexColor);

            // texture
            gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
            gl.vertexAttribPointer(
            programInfo.attribLocations.textureCoord,
                2,  // num components
                gl.FLOAT,
                false,  // don't normalize
                sizeof_vertex, // stride
                offset_uv,  // offset
            );
            gl.enableVertexAttribArray(programInfo.attribLocations.textureCoord);

            // Tell WebGL to use our program when drawing
            gl.useProgram(shaderProgram);

            // Set the shader uniforms
            gl.uniformMatrix4fv(
            programInfo.uniformLocations.matrix,
            false,
            matrix,
            );

            if (textureId != 0) {
                gl.activeTexture(gl.TEXTURE0);
                gl.bindTexture(gl.TEXTURE_2D, textures.get(textureId)[0]);
                gl.uniform1i(programInfo.uniformLocations.useTex, 1);
            } else {
                gl.bindTexture(gl.TEXTURE_2D, null);
                gl.uniform1i(programInfo.uniformLocations.useTex, 0);
            }

            gl.uniform1i(programInfo.uniformLocations.uSampler, 0);

            //console.log("drawElements " + textureId);
            gl.drawElements(gl.TRIANGLES, indices.length, gl.UNSIGNED_SHORT, 0);

	    if (clip === 1) {
		//gl.scissor(old_scissor[0], old_scissor[1], old_scissor[2], old_scissor[3]);
		gl.scissor(0, 0, renderTargetSize[0], renderTargetSize[1]);
	    }
        },
        wasm_cursor(name_ptr, name_len) {
            let cursor_name = utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, name_ptr, name_len));
            gl.canvas.style.cursor = cursor_name;
        },
        wasm_text_input(x, y, w, h) {
            if (w > 0 && h > 0) {
                textInputRect = [x, y, w, h];
            } else {
                textInputRect = [];
            }
        },
        wasm_open_url: (ptr, len) => {
            let url = utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, len));
	    window.open(url);
        },
        wasm_download_data: (name_ptr, name_len, data_ptr, data_len) => {
            const name = utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, name_ptr, name_len));
	    const data = new Uint8Array(wasmResult.instance.exports.memory.buffer, data_ptr, data_len);
	    const blob = new Blob([data], { type: "octet/stream" });
	    const fileURL = URL.createObjectURL(blob);
	    const dl = document.createElement('a');
	    dl.href = fileURL;
	    dl.download = name;
	    document.body.appendChild(dl);
	    dl.click();
	    document.body.removeChild(dl);
	    URL.revokeObjectURL(fileURL);
        },
        wasm_clipboardTextSet: (ptr, len) => {
            if (len == 0) {
                return;
            }

            let msg = utf8decoder.decode(new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, len));
            if (navigator.clipboard) {
                navigator.clipboard.writeText(msg);
            } else {
                hidden_input.value = msg;
                hidden_input.focus();
                hidden_input.select();
                document.execCommand("copy");
                hidden_input.value = "";
                oskCheck();
            }
        },
	wasm_add_noto_font: () => {
	    dvui_fetch("NotoSansKR-Regular.ttf").then((bytes) => {
		    //console.log("bytes len " + bytes.length);
		    const ptr = wasmResult.instance.exports.gpa_u8(bytes.length);
		    var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, bytes.length);
		    dest.set(bytes);
		    wasmResult.instance.exports.new_font(ptr, bytes.length);
	    });
        },
      },
    };

    fetch(wasmFile)
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, imports))
    .then(result => {

        wasmResult = result;
		cli2ser=result.instance.exports.cli2ser_ptr();
		ser2cli=result.instance.exports.ser2cli_ptr();
		wasm_strbuf = result.instance.exports.strbuf_ptr();
		teilnehmer_buf = result.instance.exports.teilnehmer_ptr();
		version_ptr = result.instance.exports.version_ptr();
		console.log("teilnehmer_buf:", teilnehmer_buf);
		console.log("wasm_strbuf:", wasm_strbuf);
		//dest2.set(new TextEncoder("utf-8").encode("hello"));
		
				sb_arr = new Uint8Array(wasmResult.instance.exports.memory.buffer, wasm_strbuf , 6);
//				sb_arr[0] = 115;
		ws = new WebSocket("ws://localhost:3001/chat");
		//ws = new WebSocket("wss://beepdoop.uber.space/tsg-zeltlager");
		ws.binaryType = 'arraybuffer';
		ws.onmessage = function messagehandler(e){
			if (e.data == lastmessage)return;
			message = new Uint8Array(e.data);
			if (message[0] == cmd_request_state){
				//lastmessage=e.data;
				//let offset =i32(new Uint8Array(e.data,1));
				//console.log(offset);
				//console.log(new TextDecoder().decode(message.slice(5,100)));

				xyz = new Uint8Array(wasmResult.instance.exports.memory.buffer, wasm_strbuf);
				console.log("mslice:", message.slice(0,message.length));
				xyz.set(message);

		//		console.log("sb_arr: ", sb_arr[0]);
			    //xyz[0] = 110;
			}
			else if (message[0] == 10) {
//        		wasmResult.instance.exports.store_config();
				console.log("get teilnehmer pointers");
				console.log(teilnehmer_buf);
		//		version = message[1] + (message[2] << 8);
				v_ptr = new Uint8Array(wasmResult.instance.exports.memory.buffer, version_ptr);
				v_ptr[0] = message[4];		
				v_ptr[1] = message[5];
				xyz = new Uint8Array(wasmResult.instance.exports.memory.buffer, teilnehmer_buf);

				xyz.set(message.slice(8,message.length ))
//				wasmResult.instance.exports.adjust_ptrs(message.length / 35*4);
				console.log("n_teilnehmer", (message.length-8) / (35*4));
				wasmResult.instance.exports.adjust_ptrs((message.length-8)/(35*4));
			}
			else {
				xyz = new Uint8Array(wasmResult.instance.exports.memory.buffer, ser2cli);
				xyz.set(message);
				result.instance.exports.receive_websocket(message.length);
			}

                requestRender();
		}	
		ws.onclose = function(e) { 
			setTimeout( startws,1000);
		};
		ws.onopen = function(e) { 
			console.log("ws_open");
			ws.send(new Uint8Array([cmd_request_state]));
		};



//		ws.send(new Uint8Array([cmd_synch, version>>8, version]))
		//sb_arr[0] = 100;
		//sb_arr.set(new TextEncoder("utf-8").encode("hello"),0);
        const canvas = document.querySelector(canvasId);

        hidden_input = document.createElement("input");
	hidden_input.style.position = "absolute";
	hidden_input.style.left = 0;
	hidden_input.style.top = 0;
        hidden_input.style.opacity = 0;
        hidden_input.style.zIndex = -1;
	document.body.prepend(hidden_input);

        gl = canvas.getContext("webgl2", { alpha: true });
        if (gl === null) {
            webgl2 = false;
            gl = canvas.getContext("webgl", { alpha: true });
        }

        if (gl === null) {
            alert("Unable to initialize WebGL.");
            return;
        }

        if (!webgl2) {
            const ext = gl.getExtension("OES_element_index_uint");
            if (ext === null) {
                alert("WebGL doesn't support OES_element_index_uint.");
                return;
            }
        }

	frame_buffer = gl.createFramebuffer();

        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
        if (webgl2) {
            gl.shaderSource(vertexShader, vertexShaderSource_webgl2);
        } else {
            gl.shaderSource(vertexShader, vertexShaderSource_webgl);
        }
        gl.compileShader(vertexShader);
        if (!gl.getShaderParameter(vertexShader, gl.COMPILE_STATUS)) {
            alert(`Error compiling vertex shader: ${gl.getShaderInfoLog(vertexShader)}`);
            gl.deleteShader(vertexShader);
            return null;
        }

        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
        if (webgl2) {
            gl.shaderSource(fragmentShader, fragmentShaderSource_webgl2);
        } else {
            gl.shaderSource(fragmentShader, fragmentShaderSource_webgl);
        }
        gl.compileShader(fragmentShader);
        if (!gl.getShaderParameter(fragmentShader, gl.COMPILE_STATUS)) {
            alert(`Error compiling fragment shader: ${gl.getShaderInfoLog(fragmentShader)}`);
            gl.deleteShader(fragmentShader);
            return null;
        }

        shaderProgram = gl.createProgram();
        gl.attachShader(shaderProgram, vertexShader);
        gl.attachShader(shaderProgram, fragmentShader);
        gl.linkProgram(shaderProgram);

        if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
            alert(`Error initializing shader program: ${gl.getProgramInfoLog(shaderProgram)}`);
            return null;
        }

        programInfo = {
            attribLocations: {
                vertexPosition: gl.getAttribLocation(shaderProgram, "aVertexPosition"),
                vertexColor: gl.getAttribLocation(shaderProgram, "aVertexColor"),
                textureCoord: gl.getAttribLocation(shaderProgram, "aTextureCoord"),
            },
            uniformLocations: {
                matrix: gl.getUniformLocation(shaderProgram, "uMatrix"),
                uSampler: gl.getUniformLocation(shaderProgram, "uSampler"),
                useTex: gl.getUniformLocation(shaderProgram, "useTex"),
            },
        };

        indexBuffer = gl.createBuffer();
        vertexBuffer = gl.createBuffer();

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
        gl.enable(gl.SCISSOR_TEST);
        gl.scissor(0, 0, gl.canvas.clientWidth, gl.canvas.clientHeight);

        let renderRequested = false;
        let renderTimeoutId = 0;
        let app_initialized = false;

        function render() {
            renderRequested = false;

            // if the canvas changed size, adjust the backing buffer
            const w = gl.canvas.clientWidth;
            const h = gl.canvas.clientHeight;
            const scale = window.devicePixelRatio;
            //console.log("wxh " + w + "x" + h + " scale " + scale);
            gl.canvas.width = Math.round(w * scale);
            gl.canvas.height = Math.round(h * scale);
	    renderTargetSize = [gl.drawingBufferWidth, gl.drawingBufferHeight];
            gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
            gl.scissor(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);

            gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
            gl.clear(gl.COLOR_BUFFER_BIT);

            if (!app_initialized) {
                app_initialized = true;
	        let app_init_return = 0;
	        let str = utf8encoder.encode(navigator.platform);
                if (str.length > 0) {
                    const ptr = wasmResult.instance.exports.gpa_u8(str.length);
                    var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, str.length);
                    dest.set(str);
                    app_init_return = wasmResult.instance.exports.app_init(ptr, str.length);
		    wasmResult.instance.exports.gpa_free(ptr, str.length);
		} else {
                    app_init_return = wasmResult.instance.exports.app_init(0, 0);
		}

		if (app_init_return != 0) {
		    console.log("ERROR: app_init returned " + app_init_return);
		    return;
		}
            }

            let millis_to_wait = wasmResult.instance.exports.app_update();
            if (millis_to_wait == 0) {
                requestRender();
            } else if (millis_to_wait > 0) {
                renderTimeoutId = setTimeout(function () { renderTimeoutId = 0; requestRender(); }, millis_to_wait);
            }
            // otherwise something went wrong, so stop
        }

        function requestRender() {
            if (renderTimeoutId > 0) {
                // we got called before the timeout happened
                clearTimeout(renderTimeoutId);
                renderTimeoutId = 0;
            }

            if (!renderRequested) {
                // multiple events could call requestRender multiple times, and
                // we only want a single requestAnimationFrame to happen before
                // each call to app_update
                renderRequested = true;
                requestAnimationFrame(render);
            }
        }

        // event listeners
        canvas.addEventListener("contextmenu", (ev) => {
            ev.preventDefault();
        });
        window.addEventListener("resize", (ev) => {
            requestRender();
        });
		window.onbeforeunload = function() {
        	wasmResult.instance.exports.store_config();
			let dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, wasmResult.instance.exports.theme_ptr(), 1);
			localStorage.setItem('theme',dest[0]);

		}
/*		document.getElementById("button").addEventListener("click", (ev) => {
        	wasmResult.instance.exports.store_config();
			let dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, wasmResult.instance.exports.theme_ptr(), 1);
			//localStorage.setItem('theme',dest[0]);
			{
				let data = "js_to_wasm";
				let data_len = data.length
            	let dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ser2cli, data_len+1);
				dest[0]=data_len;
				dest.set(new TextEncoder("utf-8").encode(data),1);
            	
			}
			{
				let data_len = wasmResult.instance.exports.js_msg();
				let dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, cli2ser, data_len);
				console.log(new TextDecoder("utf-8").decode(dest))
			}
            requestRender();
        });
*/
        canvas.addEventListener("mousemove", (ev) => {
            let rect = canvas.getBoundingClientRect();
            let x = (ev.clientX - rect.left) / (rect.right - rect.left) * canvas.clientWidth;
            let y = (ev.clientY - rect.top) / (rect.bottom - rect.top) * canvas.clientHeight;
            wasmResult.instance.exports.add_event(1, 0, 0, x, y);
			//console.log("mousemove");
            requestRender();
        });
        canvas.addEventListener("mousedown", (ev) => {
            wasmResult.instance.exports.add_event(2, ev.button, 0, 0, 0);
            requestRender();
        });
        canvas.addEventListener("mouseup", (ev) => {
            wasmResult.instance.exports.add_event(3, ev.button, 0, 0, 0);
            requestRender();
            oskCheck();
        });
        canvas.addEventListener("wheel", (ev) => {
	    ev.preventDefault();
            wasmResult.instance.exports.add_event(4, 0, 0, ev.deltaY, 0);
            requestRender();
        });

        let keydown = function(ev) {
            if (ev.key == "Tab") {
                // stop tab from tabbing away from the canvas
                ev.preventDefault();
            }

            let str = utf8encoder.encode(ev.key);
            if (str.length > 0) {
                const ptr = wasmResult.instance.exports.arena_u8(str.length);
                var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, str.length);
                dest.set(str);
                wasmResult.instance.exports.add_event(5, ptr, str.length, ev.repeat, (ev.metaKey << 3) + (ev.altKey << 2) + (ev.ctrlKey << 1) + (ev.shiftKey << 0));
                requestRender();
            }
        };
        canvas.addEventListener("keydown", keydown);
        hidden_input.addEventListener("keydown", keydown);

        let keyup = function(ev) {
            const str = utf8encoder.encode(ev.key);
            const ptr = wasmResult.instance.exports.arena_u8(str.length);
            var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, str.length);
            dest.set(str);
            wasmResult.instance.exports.add_event(6, ptr, str.length, 0, (ev.metaKey << 3) + (ev.altKey << 2) + (ev.ctrlKey << 1) + (ev.shiftKey << 0));
            requestRender();
        };
        canvas.addEventListener("keyup", keyup);
        hidden_input.addEventListener("keyup", keyup);

        hidden_input.addEventListener("beforeinput", (ev) => {
            ev.preventDefault();
            if (ev.data) {
                const str = utf8encoder.encode(ev.data);
                const ptr = wasmResult.instance.exports.arena_u8(str.length);
                var dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, ptr, str.length);
                dest.set(str);
                wasmResult.instance.exports.add_event(7, ptr, str.length, 0, 0);
                requestRender();
            }
        });
        canvas.addEventListener("touchstart", (ev) => {
            ev.preventDefault();
            let rect = canvas.getBoundingClientRect();
            for (let i = 0; i < ev.changedTouches.length; i++) {
                let touch = ev.changedTouches[i];
                let x = (touch.clientX - rect.left) / (rect.right - rect.left);
                let y = (touch.clientY - rect.top) / (rect.bottom - rect.top);
                let tidx = touchIndex(touch.identifier);
                wasmResult.instance.exports.add_event(8, touches[tidx][1], 0, x, y);
            }
            requestRender();
        });
        canvas.addEventListener("touchend", (ev) => {
            ev.preventDefault();
            let rect = canvas.getBoundingClientRect();
            for (let i = 0; i < ev.changedTouches.length; i++) {
                let touch = ev.changedTouches[i];
                let x = (touch.clientX - rect.left) / (rect.right - rect.left);
                let y = (touch.clientY - rect.top) / (rect.bottom - rect.top);
                let tidx = touchIndex(touch.identifier);
                wasmResult.instance.exports.add_event(9, touches[tidx][1], 0, x, y);
                touches.splice(tidx, 1);
            }
            requestRender();
            oskCheck();
        });
        canvas.addEventListener("touchmove", (ev) => {
            ev.preventDefault();
            let rect = canvas.getBoundingClientRect();
            for (let i = 0; i < ev.changedTouches.length; i++) {
                let touch = ev.changedTouches[i];
                let x = (touch.clientX - rect.left) / (rect.right - rect.left);
                let y = (touch.clientY - rect.top) / (rect.bottom - rect.top);
                let tidx = touchIndex(touch.identifier);
                wasmResult.instance.exports.add_event(10, touches[tidx][1], 0, x, y);
            }
            requestRender();
        });
        //canvas.addEventListener("touchcancel", (ev) => {
        //    console.log(ev);
        //    requestRender();
        //});

        // start the first update
		
		theme_ptr = result.instance.exports.theme_ptr();
		let dest = new Uint8Array(wasmResult.instance.exports.memory.buffer, theme_ptr, 1);
		dest[0] = localStorage.getItem("theme");
		requestRender();
    });
}

