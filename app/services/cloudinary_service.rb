class CloudinaryService
  # Max file size: 5MB
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_FORMATS = %w[jpg jpeg png gif webp].freeze

  class << self
    # Upload a profile picture to Cloudinary
    # file: can be an ActionDispatch::Http::UploadedFile or a file path
    # user_id: used for organizing in cloudinary folder
    def upload_profile_pic(file, user_id)
      validate_file!(file)

      result = Cloudinary::Uploader.upload(file, {
        folder: "tutorconnect/profiles",
        public_id: "user_#{user_id}_#{Time.current.to_i}",
        overwrite: true,
        resource_type: "image",
        transformation: [
          { width: 400, height: 400, crop: "fill", gravity: "face" },
          { quality: "auto", fetch_format: "auto" }
        ]
      })

      result["secure_url"]
    rescue CloudinaryException => e
      Rails.logger.error "Cloudinary upload error: #{e.message}"
      raise UploadError, "Failed to upload image. Please try again."
    end

    # Delete old profile picture from Cloudinary
    def delete_image(url)
      return unless url.present? && url.include?("cloudinary")

      # Extract public_id from the URL
      public_id = extract_public_id(url)
      return unless public_id

      Cloudinary::Uploader.destroy(public_id)
    rescue StandardError => e
      Rails.logger.error "Cloudinary delete error: #{e.message}"
      # Don't raise — deletion failure shouldn't block the user
    end

    private

    def validate_file!(file)
      if file.respond_to?(:size)
        raise UploadError, "File is too large. Maximum size is 5MB." if file.size > MAX_FILE_SIZE
      end

      if file.respond_to?(:content_type)
        ext = file.content_type&.split("/")&.last&.downcase
        unless ALLOWED_FORMATS.include?(ext)
          raise UploadError, "Invalid file format. Allowed: #{ALLOWED_FORMATS.join(', ')}"
        end
      end
    end

    def extract_public_id(url)
      # Cloudinary URLs look like: .../upload/v1234/folder/public_id.ext
      match = url.match(%r{/upload/(?:v\d+/)?(.+)\.\w+$})
      match&.[](1)
    end
  end

  class UploadError < StandardError; end
end
