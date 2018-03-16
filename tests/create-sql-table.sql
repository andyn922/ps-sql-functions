USE [LocalTestDB]
GO
/****** Object:  Table [dbo].[TestTable1]    Script Date: 13/07/2016 11:26:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TestTable1](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nvarchar](50) NOT NULL,
	[value] [nvarchar](50) NOT NULL,
	[bool-alpha] [bit] NULL,
	[bool-bravo] [bit] NULL,
	[bool-charlie] [bit] NULL
) ON [PRIMARY]

GO
