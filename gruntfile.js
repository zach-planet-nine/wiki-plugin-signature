module.exports = function (grunt) {
  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-mocha-test');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-git-authors');
  grunt.loadNpmTasks('grunt-contrib-coffee');

  grunt.initConfig({
    clean: ['client/signature2.js', 'client/signature2.js.map', 'server/server.js', 'test/test.js', 'test/test.js.map'],

    browserify: {
      client: { 
	src: ['client/signature2.coffee'],
	dest: 'client/signature2.js',
	options: {
	  transform: ['coffeeify'],
	  browserifyOptions: {
	    extensions: ".coffee"
	  }
	}
      }
    },

    coffee: {
      compile: {
	files: {
	  'server/server.js': 'server/server.coffee'
	}
      }
    },

    mochaTest: {
      test: {
        options: {
          reporter: 'spec',
          require: 'coffeescript/register'
        },
        src: ['test/test.coffee']
      }
    },


    watch: {
      all: {
        files: ['client/*.coffee', 'test/*.coffee'],
        tasks: ['build']
      }
    }
  });

  grunt.registerTask('build', ['clean', 'mochaTest', 'browserify:client', 'coffee']);
  grunt.registerTask('default', ['build']);

};
